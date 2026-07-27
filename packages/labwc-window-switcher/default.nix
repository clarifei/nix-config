{
  coreutils,
  curl,
  foot,
  focusSignal ? "${util-linux}/bin/kill",
  fzf,
  lib,
  util-linux,
  writeShellApplication,
}:

let
  switcherTui = writeShellApplication {
    name = "labwc-window-switcher-tui";
    runtimeInputs = [ fzf ];
    text = ''
      if (( $# != 4 )); then
        exit 2
      fi

      candidates=$1
      selection_file=$2
      control_socket=$3
      direction=$4

      start_action=first
      if [[ $direction == previous ]]; then
        start_action=last
      fi

      selection=
      if selection=$(
        ${lib.getExe fzf} \
          --no-multi \
          --layout=reverse \
          --border=sharp \
          --info=inline-right \
          --prompt='window  ' \
          --pointer='>' \
          --marker='+' \
          --cycle \
          --no-hscroll \
          --scroll-off=2 \
          --listen="$control_socket" \
          --bind="start:$start_action" \
          --bind='tab:down,shift-tab:up' \
          --delimiter=$'\t' \
          --with-nth='2..' \
          --color='16,border:8,prompt:4,pointer:6,marker:2,hl:3,hl+:3' \
          < "$candidates"
      ); then
        printf '%s\n' "$selection" > "$selection_file"
      fi
    '';
  };
in
writeShellApplication {
  name = "labwc-window-switcher";
  runtimeInputs = [
    coreutils
    curl
    util-linux
  ];
  text = ''
    umask 077

    if (( $# > 1 )); then
      exit 2
    fi
    mode=''${1:-next}
    case $mode in
      next)
        move_action=down
        ;;
      previous)
        move_action=up
        ;;
      accept | cancel)
        move_action=$mode
        ;;
      *)
        exit 2
        ;;
    esac

    generation=''${LABWC_WINDOW_SWITCHER_GENERATION:-}
    labwc_pid=''${LABWC_PID:-}
    if [[ ! $generation =~ ^([1-9][0-9]*)-([1-9][0-9]*)-([1-9][0-9]*)-([1-9][0-9]*)$ ]]; then
      exit 0
    fi
    generation_pid=''${BASH_REMATCH[1]}
    generation_start_time=''${BASH_REMATCH[2]}
    generation_pidfd_inode=''${BASH_REMATCH[3]}
    if [[ ! $labwc_pid =~ ^[1-9][0-9]*$ || $labwc_pid != "$generation_pid" ]]; then
      exit 0
    fi

    process_start_time() {
      local pid=$1
      local process_stat
      local -a stat_fields
      [[ $pid =~ ^[1-9][0-9]*$ && -r /proc/$pid/stat ]] || return 1
      IFS= read -r process_stat < "/proc/$pid/stat" || return 1
      process_stat=''${process_stat##*) }
      read -r -a stat_fields <<< "$process_stat"
      (( ''${#stat_fields[@]} > 19 )) || return 1
      printf '%s\n' "''${stat_fields[19]}"
    }

    process_matches_record() {
      local pid=$1
      local expected_start=$2
      local current_start
      current_start=$(process_start_time "$pid") || return 1
      [[ $current_start == "$expected_start" ]]
    }

    # LABWC_PID can be recycled while an orphaned chooser is still alive.
    # Match the process start time embedded by Labwc before sending any signal.
    if ! process_matches_record "$labwc_pid" "$generation_start_time"; then
      exit 0
    fi

    switcher_runtime=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    if [[ ! -d $switcher_runtime || ! -O $switcher_runtime ]]; then
      echo "labwc-window-switcher: no private runtime directory" >&2
      exit 1
    fi

    state_root="$switcher_runtime/labwc-window-switcher"
    state_dir="$state_root/$generation"
    control_socket="$state_dir/fzf.sock"
    running_file="$state_dir/running"
    lock_file="$state_root/lock.$generation"
    foot_pid_file="$state_dir/foot.pid"
    export_file="$switcher_runtime/labwc-window-switcher-windows.$generation"
    focus_file="$switcher_runtime/labwc-window-switcher-focus.$generation"

    if [[ $mode == accept || $mode == cancel ]] \
      && [[ ! -e $running_file && ! -e $export_file && ! -e $control_socket ]]
    then
      exit 0
    fi

    mkdir -p -- "$state_root" "$state_dir"
    chmod 0700 -- "$state_root" "$state_dir"

    post_action() {
      local action=$1
      ${lib.getExe curl} \
        --silent \
        --fail \
        --max-time 0.25 \
        --unix-socket "$control_socket" \
        -X POST \
        http://localhost \
        -d "$action" \
        >/dev/null 2>&1
    }

    wait_and_post() {
      local action=$1
      local takeover_fd=''${2:-}
      local attempt
      local post_attempt=0
      for (( attempt = 0; attempt < 250; attempt++ )); do
        if [[ -n $takeover_fd ]] && flock --nonblock "$takeover_fd"; then
          return 2
        fi
        if [[ -e $control_socket ]]; then
          if post_action "$action"; then
            if [[ -n $takeover_fd ]] && flock --nonblock "$takeover_fd"; then
              return 2
            fi
            return 0
          fi
          ((post_attempt += 1))
        fi
        (( post_attempt < 5 )) || return 1
        sleep 0.01
      done
      return 1
    }

    wait_for_export_claim_or_takeover() {
      local takeover_fd=$1
      local attempt
      for (( attempt = 0; attempt < 250; attempt++ )); do
        if flock --nonblock "$takeover_fd"; then
          return 2
        fi
        [[ -e $export_file ]] || return 0
        sleep 0.01
      done
      return 1
    }

    terminate_orphan() {
      local orphan_pid orphan_start
      if [[ ! -f $foot_pid_file || ! -O $foot_pid_file ]]; then
        return 0
      fi
      orphan_pid=
      orphan_start=
      IFS=' ' read -r orphan_pid orphan_start < "$foot_pid_file" || true
      if [[ ! $orphan_pid =~ ^[1-9][0-9]*$ || ! $orphan_start =~ ^[0-9]+$ ]]; then
        rm -f -- "$foot_pid_file"
        return 0
      fi
      if ! process_matches_record "$orphan_pid" "$orphan_start"; then
        rm -f -- "$foot_pid_file"
        return 0
      fi

      if ! ${util-linux}/bin/kill \
        --timeout 500 KILL \
        --signal TERM \
        "$orphan_pid" \
        2>/dev/null
      then
        if process_matches_record "$orphan_pid" "$orphan_start"; then
          return 1
        fi
      fi
      rm -f -- "$foot_pid_file"
    }

    remove_stale_sessions() {
      local stale_session
      shopt -s nullglob
      for stale_session in "$state_dir"/session.*; do
        [[ -d $stale_session && ! -L $stale_session ]] || continue
        rm -f -- \
          "$stale_session/windows" \
          "$stale_session/candidates" \
          "$stale_session/selection" \
          "$stale_session/focus"
        rmdir -- "$stale_session" 2>/dev/null || true
      done
      shopt -u nullglob
    }

    recover_stale_export() {
      local stale_session
      [[ ! -e $export_file ]] || return 0
      shopt -s nullglob
      for stale_session in "$state_dir"/session.*; do
        if [[ -f $stale_session/windows \
          && -O $stale_session/windows \
          && ! -L $stale_session/windows
        ]]; then
          mv -- "$stale_session/windows" "$export_file"
          break
        fi
      done
      shopt -u nullglob
    }

    remove_generation_directory() {
      rm -f -- "$foot_pid_file".*
      # Keep the zero-byte generation lock until XDG runtime teardown. Removing
      # a flock path could let a late process lock a different inode.
      rmdir -- "$state_dir" 2>/dev/null || true
    }

    if [[ $mode == accept || $mode == cancel ]]; then
      # ExportWindowList creates export_file before Labwc starts this process,
      # so a quick modifier release cannot race ahead of the terminal startup.
      # The initial owner may not have taken its lock yet. The generation-local
      # export lets this release wait safely without reaching a later session.
      if [[ -e $export_file ]] && wait_and_post "$move_action"; then
        exit 0
      fi

      # The lock is authoritative: marker files and sockets can survive SIGKILL.
      exec {release_lock_fd}> "$lock_file"
      if ! flock --nonblock "$release_lock_fd"; then
        release_status=0
        wait_and_post "$move_action" "$release_lock_fd" || release_status=$?
        if (( release_status == 0 )); then
          exit 0
        fi
        if (( release_status != 2 )) && ! flock --nonblock "$release_lock_fd"; then
          exit 0
        fi
      fi
      terminate_orphan || exit 1
      rm -f -- "$control_socket" "$running_file" "$export_file"
      remove_stale_sessions
      remove_generation_directory
      exit 0
    fi

    exec {lock_fd}> "$lock_file"
    if ! flock --nonblock "$lock_fd"; then
      wait_status=0
      if [[ -e $export_file ]]; then
        wait_for_export_claim_or_takeover "$lock_fd" || wait_status=$?
      fi
      if (( wait_status == 0 )); then
        wait_and_post "$move_action" "$lock_fd" || wait_status=$?
        if (( wait_status == 0 )); then
          exit 0
        fi
      fi
      if (( wait_status != 2 )) && ! flock --nonblock "$lock_fd"; then
        exit 0
      fi
      if [[ ! -e $running_file && ! -e $control_socket && ! -e $export_file ]]; then
        remove_generation_directory
        exit 0
      fi
    fi

    if [[ ! -e $running_file && ! -e $control_socket && ! -e $export_file ]]; then
      remove_generation_directory
      exit 0
    fi

    # No wrapper owns the lock. Stop the precisely recorded Foot child before
    # reusing this generation's socket and state.
    if [[ -e $control_socket ]]; then
      post_action cancel || true
    fi
    terminate_orphan || exit 1
    recover_stale_export
    rm -f -- "$control_socket" "$running_file"
    remove_stale_sessions

    : > "$running_file"
    session_dir=
    foot_pid=

    # shellcheck disable=SC2329 # Invoked by the EXIT trap below.
    cleanup() {
      if [[ -n $foot_pid ]] && ! terminate_orphan; then
        return
      fi
      rm -f -- "$control_socket" "$running_file" "$export_file" "$foot_pid_file"
      if [[ -n $session_dir ]]; then
        rm -f -- \
          "$session_dir/windows" \
          "$session_dir/candidates" \
          "$session_dir/selection" \
          "$session_dir/focus"
        rmdir -- "$session_dir" 2>/dev/null || true
      fi
      remove_generation_directory
    }
    trap cleanup EXIT
    trap 'exit 130' HUP INT TERM

    rm -f -- "$control_socket"
    session_dir=$(mktemp --directory --tmpdir="$state_dir" session.XXXXXX)
    windows_file="$session_dir/windows"
    candidates_file="$session_dir/candidates"
    selection_file="$session_dir/selection"

    [[ -f $export_file && -O $export_file && ! -L $export_file ]] || exit 0
    mv -- "$export_file" "$windows_file"

    : > "$candidates_file"
    while IFS= read -r -d "" window_id \
      && IFS= read -r -d "" active \
      && IFS= read -r -d "" workspace \
      && IFS= read -r -d "" app_id \
      && IFS= read -r -d "" title; do
      [[ $active != 1 ]] || continue
      [[ -n $app_id && $app_id != labwc-window-switcher ]] || continue

      display_workspace=$workspace
      display_app_id=$app_id
      display_title=$title
      control_characters=[$'\001'-$'\037'$'\177']
      display_workspace=''${display_workspace//$control_characters/ }
      display_app_id=''${display_app_id//$control_characters/ }
      display_title=''${display_title//$control_characters/ }
      printf '%s\t[%s]  %s  %s\n' \
        "$window_id" "$display_workspace" "$display_app_id" "$display_title" \
        >> "$candidates_file"
    done < "$windows_file"

    [[ -s $candidates_file ]] || exit 0

    (
      foot_process_pid=$BASHPID
      foot_start=$(process_start_time "$foot_process_pid") || exit 1
      foot_pid_tmp="$foot_pid_file.$foot_process_pid"
      printf '%s %s\n' "$foot_process_pid" "$foot_start" > "$foot_pid_tmp"
      mv -- "$foot_pid_tmp" "$foot_pid_file"
      exec {lock_fd}>&-
      exec ${lib.getExe foot} \
        --app-id=labwc-window-switcher \
        --title='Switch window' \
        --override=main.initial-window-size-pixels=820x420 \
        ${lib.getExe switcherTui} \
        "$candidates_file" "$selection_file" "$control_socket" "$mode"
    ) >/dev/null 2>&1 &
    foot_pid=$!
    wait "$foot_pid" || true
    foot_pid=
    rm -f -- "$foot_pid_file"

    [[ -s $selection_file ]] || exit 0
    selection=
    IFS= read -r selection < "$selection_file" || true
    [[ $selection == *$'\t'* ]] || exit 1
    selection_id=''${selection%%$'\t'*}
    [[ $selection_id =~ ^[0-9]+$ ]] || exit 1

    selection_found=0
    while IFS= read -r -d "" window_id \
      && IFS= read -r -d "" active \
      && IFS= read -r -d "" workspace \
      && IFS= read -r -d "" app_id \
      && IFS= read -r -d "" title; do
      if [[ $window_id == "$selection_id" ]]; then
        selection_found=1
        break
      fi
    done < "$windows_file"
    (( selection_found == 1 )) || exit 1

    printf '%s\n' "$selection_id" > "$session_dir/focus"
    mv -- "$session_dir/focus" "$focus_file"
    if ! process_matches_record "$labwc_pid" "$generation_start_time" \
      || ! ${focusSignal} -USR1 -- "$labwc_pid:$generation_pidfd_inode"
    then
      rm -f -- "$focus_file"
      exit 1
    fi
    for (( attempt = 0; attempt < 100; attempt++ )); do
      [[ -e $focus_file ]] || exit 0
      if [[ ! -s $focus_file ]]; then
        rm -f -- "$focus_file"
        exit 1
      fi
      sleep 0.01
    done
    rm -f -- "$focus_file"
    exit 1
  '';
}
