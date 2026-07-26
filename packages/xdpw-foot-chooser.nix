{
  coreutils,
  foot,
  fzf,
  gnused,
  lib,
  util-linux,
  writeShellApplication,
}:

let
  chooserTui = writeShellApplication {
    name = "xdpw-foot-chooser-tui";
    runtimeInputs = [ fzf ];
    text = ''
      if (( $# != 2 )); then
        exit 2
      fi

      candidates=$1
      selection_file=$2

      selection=
      if selection=$(
        fzf \
          --no-multi \
          --layout=reverse \
          --border=sharp \
          --info=inline-right \
          --prompt='Share: ' \
          --pointer='>' \
          --marker='+' \
          --color='16,border:8,prompt:4,pointer:6,marker:2,hl:3,hl+:3' \
          < "$candidates"
      ); then
        printf '%s\n' "$selection" > "$selection_file"
      fi
    '';
  };
in
writeShellApplication {
  name = "xdpw-foot-chooser";
  runtimeInputs = [
    coreutils
    foot
    gnused
    util-linux
  ];
  text = ''
    umask 077

    # xdpw can receive overlapping source requests while Chromium is preparing a preview and
    # the final stream. Serialize the UI and only reuse a result for requests that started before
    # the active chooser finished. A later workflow must always get a fresh selection.
    chooser_runtime=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    if [[ ! -d $chooser_runtime || ! -O $chooser_runtime ]]; then
      echo "xdpw-foot-chooser: no private runtime directory" >&2
      exit 1
    fi
    chooser_state_dir="$chooser_runtime/xdpw-foot-chooser"
    results_dir="$chooser_state_dir/results"
    pending_dir="$chooser_state_dir/pending"
    mkdir -p -- "$results_dir" "$pending_dir"
    chmod 700 -- "$chooser_state_dir" "$results_dir" "$pending_dir"
    sequence_lock_file="$chooser_state_dir/sequence.lock"
    sequence_file="$chooser_state_dir/sequence"
    ui_lock_file="$chooser_state_dir/ui.lock"

    chooser_dir=$(mktemp --directory --tmpdir="$chooser_runtime" xdpw-foot-chooser.XXXXXX)
    candidates="$chooser_dir/candidates"
    selection_file="$chooser_dir/selection"
    sequence_tmp="$chooser_state_dir/sequence.$$"
    pending_file=
    result_tmp=

    cleanup() {
      rm -f -- "$candidates" "$selection_file" "$sequence_tmp"
      [[ -z $pending_file ]] || rm -f -- "$pending_file"
      [[ -z $result_tmp ]] || rm -f -- "$result_tmp"
      rmdir -- "$chooser_dir" 2>/dev/null || true
    }
    trap cleanup EXIT
    trap 'exit 130' HUP INT TERM

    cat > "$candidates"
    [[ -s $candidates ]] || exit 0
    # Window titles may change between overlapping requests (for example, a terminal spinner).
    # Hash stable target identities so those requests still share one selection transaction.
    candidate_hash=$(
      sed --regexp-extended \
        --expression='s/^Window: .* \(([^()]*)\)$/Window: \1/' \
        --expression='s/^Monitor: ([^ ]+).*/Monitor: \1/' \
        "$candidates" \
        | sha256sum
    )
    candidate_hash=''${candidate_hash%% *}

    resolve_selection() {
      local saved=$1
      local candidate window_identifier monitor_name

      window_identifier=
      monitor_name=
      if [[ $saved =~ ^Window:\ .*\ \(([^()]*)\)$ ]]; then
        window_identifier=''${BASH_REMATCH[1]}
      elif [[ $saved == Monitor:\ * ]]; then
        monitor_name=''${saved#Monitor: }
        monitor_name=''${monitor_name%% *}
      fi

      while IFS= read -r candidate || [[ -n $candidate ]]; do
        if [[ $candidate == "$saved" ]] \
          || { [[ -n $window_identifier ]] && [[ $candidate == "Window: "*" ($window_identifier)" ]]; } \
          || { [[ -n $monitor_name ]] \
            && [[ $candidate == "Monitor: $monitor_name" || $candidate == "Monitor: $monitor_name "* ]]; }; then
          printf '%s\n' "$candidate"
          return 0
        fi
      done < "$candidates"

      return 1
    }

    # Allocate an ordered ticket before waiting for the UI. The sequence lock is held only for
    # this short update, so requests can queue while another request owns the UI lock.
    exec {sequence_fd}> "$sequence_lock_file"
    flock --exclusive "$sequence_fd"
    sequence=0
    if [[ -r $sequence_file ]]; then
      IFS= read -r sequence < "$sequence_file" || true
      [[ $sequence =~ ^[0-9]+$ ]] || sequence=0
    fi
    request_ticket=$((sequence + 1))
    printf '%s\n' "$request_ticket" > "$sequence_tmp"
    mv -- "$sequence_tmp" "$sequence_file"
    pending_file="$pending_dir/$request_ticket"
    : > "$pending_file"
    flock --unlock "$sequence_fd"

    exec {ui_fd}> "$ui_lock_file"
    flock --exclusive "$ui_fd"

    # Keep completed transaction intervals until every older ticket has exited. This makes the
    # protocol independent of the order in which flock wakes its waiters.
    minimum_pending=$request_ticket
    shopt -s nullglob
    for pending in "$pending_dir"/*; do
      pending_ticket=''${pending##*/}
      if [[ $pending_ticket =~ ^[0-9]+$ ]] && (( pending_ticket < minimum_pending )); then
        minimum_pending=$pending_ticket
      fi
    done
    for old_result in "$results_dir"/*.result; do
      old_cutoff=
      IFS= read -r old_cutoff < "$old_result" || true
      if [[ $old_cutoff =~ ^[0-9]+$ ]] && (( old_cutoff < minimum_pending )); then
        rm -f -- "$old_result"
      fi
    done

    result_file=
    result_leader=
    result_status=
    result_selection=
    for candidate_result in "$results_dir/$candidate_hash".*.result; do
      candidate_cutoff=
      candidate_leader=
      candidate_status=
      candidate_selection=
      {
        IFS= read -r candidate_cutoff || true
        IFS= read -r candidate_leader || true
        IFS= read -r candidate_status || true
        IFS= read -r candidate_selection || true
      } < "$candidate_result"
      if [[ $candidate_cutoff =~ ^[0-9]+$ && $candidate_leader =~ ^[0-9]+$ ]] \
        && (( candidate_leader <= request_ticket && request_ticket <= candidate_cutoff )) \
        && { [[ -z $result_leader ]] || (( candidate_leader < result_leader )); }; then
        result_file=$candidate_result
        result_leader=$candidate_leader
        result_status=$candidate_status
        result_selection=$candidate_selection
      fi
    done

    # A result is valid only for requests that received a ticket before the transaction
    # completed. Sequential requests therefore always open a fresh chooser.
    if [[ -n $result_file ]]; then
      case "$result_status" in
        selected)
          resolved_selection=
          if resolved_selection=$(resolve_selection "$result_selection"); then
            printf '%s\n' "$resolved_selection"
            exit 0
          fi
          ;;
        cancelled)
          exit 0
          ;;
      esac
    fi

    write_result() {
      local status=$1
      local selection=''${2:-}
      local cutoff

      # Snapshot the queue while assigning the completion boundary. A request that gets a
      # ticket after this lock is released cannot consume this result.
      flock --exclusive "$sequence_fd"
      cutoff=0
      if [[ -r $sequence_file ]]; then
        IFS= read -r cutoff < "$sequence_file" || true
        [[ $cutoff =~ ^[0-9]+$ ]] || cutoff=$request_ticket
      fi
      result_file="$results_dir/$candidate_hash.$request_ticket.result"
      result_tmp="$result_file.tmp.$$"
      {
        printf '%s\n' "$cutoff" "$request_ticket" "$status"
        if [[ $status == selected ]]; then
          printf '%s\n' "$selection"
        fi
      } > "$result_tmp"
      mv -- "$result_tmp" "$result_file"
      result_tmp=
      flock --unlock "$sequence_fd"
    }

    foot \
      --app-id=xdpw-foot-chooser \
      --title='Choose what to share' \
      --override=main.initial-window-size-pixels=900x500 \
      ${lib.getExe chooserTui} "$candidates" "$selection_file" \
      >/dev/null || true

    if [[ -s $selection_file ]]; then
      selection=
      IFS= read -r selection < "$selection_file" || true
      if [[ -n $selection ]]; then
        write_result selected "$selection"
        printf '%s\n' "$selection"
        exit 0
      fi
    fi

    write_result cancelled
  '';
}
