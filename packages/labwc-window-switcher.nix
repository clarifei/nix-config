{
  coreutils,
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
      if (( $# != 2 )); then
        exit 2
      fi

      candidates=$1
      selection_file=$2

      selection=
      if selection=$(
        ${lib.getExe fzf} \
          --no-multi \
          --layout=reverse \
          --border=sharp \
          --info=inline-right \
          --prompt='Focus: ' \
          --pointer='>' \
          --marker='+' \
          --cycle \
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
    util-linux
  ];
  text = ''
    umask 077

    switcher_runtime=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    if [[ ! -d $switcher_runtime || ! -O $switcher_runtime ]]; then
      echo "labwc-window-switcher: no private runtime directory" >&2
      exit 1
    fi

    exec {lock_fd}> "$switcher_runtime/labwc-window-switcher.lock"
    flock --nonblock "$lock_fd" || exit 0

    switcher_dir=$(mktemp --directory --tmpdir="$switcher_runtime" labwc-window-switcher.XXXXXX)
    windows_file="$switcher_dir/windows"
    candidates_file="$switcher_dir/candidates"
    selection_file="$switcher_dir/selection"
    current_file="$switcher_dir/current"

    # shellcheck disable=SC2329 # Invoked by the EXIT trap below.
    cleanup() {
      rm -f -- "$windows_file" "$candidates_file" "$selection_file" "$current_file"
      rmdir -- "$switcher_dir" 2>/dev/null || true
    }
    trap cleanup EXIT
    trap 'exit 130' HUP INT TERM

    # The active window is omitted: selecting it would only return to where the chooser started.
    if ! ${lib.getExe wlrctl} toplevel list state:inactive > "$windows_file"; then
      exit 0
    fi

    candidate_index=0
    while IFS= read -r candidate || [[ -n $candidate ]]; do
      [[ $candidate == *": "* ]] || continue
      [[ $candidate == "labwc-window-switcher: "* ]] && continue
      candidate_app_id=''${candidate%%: *}
      [[ -n $candidate_app_id ]] || continue

      ((candidate_index += 1))
      # Keep the stable list position hidden from fzf while preserving it in the result.
      printf '%d\t%s\n' "$candidate_index" "$candidate" >> "$candidates_file"
    done < "$windows_file"

    [[ -s $candidates_file ]] || exit 0

    ${lib.getExe foot} \
      --app-id=labwc-window-switcher \
      --title='Switch window' \
      --override=main.initial-window-size-pixels=820x420 \
      ${lib.getExe switcherTui} "$candidates_file" "$selection_file" \
      >/dev/null || true

    [[ -s $selection_file ]] || exit 0
    selection=
    IFS= read -r selection < "$selection_file" || true
    [[ $selection == *$'\t'* ]] || exit 1

    selection_index=''${selection%%$'\t'*}
    selected_record=''${selection#*$'\t'}
    [[ $selection_index =~ ^[1-9][0-9]*$ ]] || exit 1
    [[ $selected_record == *": "* ]] || exit 1
    selected_app_id=''${selected_record%%: *}
    [[ -n $selected_app_id ]] || exit 1

    focus_record() {
      local record=$1
      local app_id title

      [[ $record == *": "* ]] || return 1
      app_id=''${record%%: *}
      title=''${record#*: }
      [[ -n $app_id ]] || return 1

      ${lib.getExe wlrctl} toplevel focus "app_id:$app_id" "title:$title"
    }

    if focus_record "$selected_record"; then
      exit 0
    fi

    # Titles can change while the TUI is open. Resolve the same list position again, then fall
    # back only when the app-id is unique, avoiding an arbitrary match between similar windows.
    if ! ${lib.getExe wlrctl} toplevel list state:inactive > "$current_file"; then
      exit 1
    fi

    current_index=0
    indexed_record=
    unique_record=
    same_app_count=0
    while IFS= read -r candidate || [[ -n $candidate ]]; do
      [[ $candidate == *": "* ]] || continue
      [[ $candidate == "labwc-window-switcher: "* ]] && continue
      candidate_app_id=''${candidate%%: *}
      [[ -n $candidate_app_id ]] || continue

      ((current_index += 1))
      if (( current_index == selection_index )); then
        indexed_record=$candidate
      fi
      if [[ $candidate_app_id == "$selected_app_id" ]]; then
        ((same_app_count += 1))
        unique_record=$candidate
      fi
    done < "$current_file"

    if [[ -n $indexed_record && ''${indexed_record%%: *} == "$selected_app_id" ]] \
      && focus_record "$indexed_record"; then
      exit 0
    fi

    if (( same_app_count == 1 )) && focus_record "$unique_record"; then
      exit 0
    fi

    exit 1
  '';
}
