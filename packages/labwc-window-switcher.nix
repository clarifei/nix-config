{
  coreutils,
  curl,
  foot,
  fzf,
  lib,
  util-linux,
  wlrctl,
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

    switcher_runtime=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    if [[ ! -d $switcher_runtime || ! -O $switcher_runtime ]]; then
      echo "labwc-window-switcher: no private runtime directory" >&2
      exit 1
    fi

    state_dir="$switcher_runtime/labwc-window-switcher"
    mkdir -p -- "$state_dir"
    chmod 0700 -- "$state_dir"

    control_socket="$state_dir/fzf.sock"
    running_file="$state_dir/running"
    lock_file="$state_dir/lock"
    export_file="$switcher_runtime/labwc-window-switcher-windows"

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
      local attempt
      for (( attempt = 0; attempt < 250; attempt++ )); do
        if post_action "$action"; then
          return 0
        fi
        sleep 0.01
      done
      return 1
    }

    if [[ $mode == accept || $mode == cancel ]]; then
      # ExportWindowList creates export_file before Labwc starts this process,
      # so a quick modifier release cannot race ahead of the terminal startup.
      if [[ ! -e $running_file && ! -e $export_file && ! -e $control_socket ]]; then
        exit 0
      fi
      if ! wait_and_post "$move_action"; then
        [[ -e $running_file ]] || rm -f -- "$export_file"
      fi
      exit 0
    fi

    if post_action "$move_action"; then
      exit 0
    fi

    exec {lock_fd}> "$lock_file"
    if ! flock --nonblock "$lock_fd"; then
      wait_and_post "$move_action" || true
      exit 0
    fi

    printf '%s\n' "$$" > "$running_file"
    session_dir=

    # shellcheck disable=SC2329 # Invoked by the EXIT trap below.
    cleanup() {
      rm -f -- "$control_socket" "$running_file" "$export_file"
      if [[ -n $session_dir ]]; then
        rm -f -- \
          "$session_dir/windows" \
          "$session_dir/candidates" \
          "$session_dir/selection" \
          "$session_dir/current"
        rmdir -- "$session_dir" 2>/dev/null || true
      fi
    }
    trap cleanup EXIT
    trap 'exit 130' HUP INT TERM

    rm -f -- "$control_socket"
    session_dir=$(mktemp --directory --tmpdir="$state_dir" session.XXXXXX)
    windows_file="$session_dir/windows"
    candidates_file="$session_dir/candidates"
    selection_file="$session_dir/selection"
    current_file="$session_dir/current"

    if [[ -f $export_file && -O $export_file ]]; then
      cp -- "$export_file" "$windows_file"
    else
      # Keep the chooser usable during a compositor upgrade before the patched
      # Labwc process has been restarted. Workspace metadata is unavailable then.
      if ! ${lib.getExe wlrctl} toplevel list state:inactive > "$current_file"; then
        exit 0
      fi
      fallback_index=0
      while IFS= read -r candidate || [[ -n $candidate ]]; do
        [[ $candidate == *": "* ]] || continue
        app_id=''${candidate%%: *}
        title=''${candidate#*: }
        [[ -n $app_id && $app_id != labwc-window-switcher ]] || continue
        ((fallback_index += 1))
        printf 'fallback-%d\0%s\0%s\0%s\0%s\0' \
          "$fallback_index" 0 '?' "$app_id" "$title" >> "$windows_file"
      done < "$current_file"
    fi
    rm -f -- "$export_file"

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
      for control_character in $'\t' $'\r' $'\n' $'\e'; do
        display_workspace=''${display_workspace//"$control_character"/ }
        display_app_id=''${display_app_id//"$control_character"/ }
        display_title=''${display_title//"$control_character"/ }
      done
      printf '%s\t[%s]  %s  %s\n' \
        "$window_id" "$display_workspace" "$display_app_id" "$display_title" \
        >> "$candidates_file"
    done < "$windows_file"

    [[ -s $candidates_file ]] || exit 0

    ${lib.getExe foot} \
      --app-id=labwc-window-switcher \
      --title='Switch window' \
      --override=main.initial-window-size-pixels=820x420 \
      ${lib.getExe switcherTui} \
      "$candidates_file" "$selection_file" "$control_socket" "$mode" \
      >/dev/null 2>&1 || true

    [[ -s $selection_file ]] || exit 0
    selection=
    IFS= read -r selection < "$selection_file" || true
    [[ $selection == *$'\t'* ]] || exit 1
    selection_id=''${selection%%$'\t'*}
    [[ -n $selection_id ]] || exit 1

    selected_app_id=
    selected_title=
    selection_found=0
    while IFS= read -r -d "" window_id \
      && IFS= read -r -d "" active \
      && IFS= read -r -d "" workspace \
      && IFS= read -r -d "" app_id \
      && IFS= read -r -d "" title; do
      if [[ $window_id == "$selection_id" ]]; then
        selected_app_id=$app_id
        selected_title=$title
        selection_found=1
        break
      fi
    done < "$windows_file"
    (( selection_found == 1 )) || exit 1

    focus_record() {
      local app_id=$1
      local title=$2
      [[ -n $app_id ]] || return 1
      ${lib.getExe wlrctl} toplevel focus "app_id:$app_id" "title:$title"
    }

    if focus_record "$selected_app_id" "$selected_title"; then
      exit 0
    fi

    # Titles can change while the TUI is open. Fall back only when the app-id
    # is unique, avoiding an arbitrary match between similar windows.
    if ! ${lib.getExe wlrctl} toplevel list state:inactive > "$current_file"; then
      exit 1
    fi

    unique_record=
    same_app_count=0
    while IFS= read -r candidate || [[ -n $candidate ]]; do
      [[ $candidate == *": "* ]] || continue
      candidate_app_id=''${candidate%%: *}
      [[ -n $candidate_app_id && $candidate_app_id != labwc-window-switcher ]] || continue
      if [[ $candidate_app_id == "$selected_app_id" ]]; then
        ((same_app_count += 1))
        unique_record=$candidate
      fi
    done < "$current_file"

    if (( same_app_count == 1 )); then
      focus_record "''${unique_record%%: *}" "''${unique_record#*: }"
      exit $?
    fi

    exit 1
  '';
}
