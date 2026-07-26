{
  callPackage,
  coreutils,
  gnused,
  runCommand,
  writeShellScriptBin,
}:

let
  fakeFoot = writeShellScriptBin "foot" ''
    set -euo pipefail

    printf 'opened\n' >> "''${FAKE_FOOT_COUNT:?}"
    while (( $# > 0 )) && [[ $1 == --* ]]; do
      shift
    done
    (( $# == 5 ))
    candidates=$2
    selection=$3
    socket=$4
    direction=$5

    ${coreutils}/bin/cp -- "$candidates" "''${FAKE_CANDIDATES_SNAPSHOT:?}"
    printf '%s\n' "$direction" >> "''${FAKE_DIRECTION_LOG:?}"
    : > "$socket"

    if [[ -n ''${FAKE_FOOT_GATE:-} ]]; then
      : > "$FAKE_FOOT_GATE.opened"
      gate_open=0
      for (( attempt = 0; attempt < 500; attempt++ )); do
        if [[ -e $FAKE_FOOT_GATE ]]; then
          gate_open=1
          break
        fi
        ${coreutils}/bin/sleep 0.01
      done
      (( gate_open == 1 ))
    fi

    [[ ''${FAKE_FOOT_CANCEL:-0} != 1 ]] || exit 0
    ${gnused}/bin/sed -n "''${FAKE_SELECTION_LINE:-1}p" "$candidates" > "$selection"
  '';

  fakeCurl = writeShellScriptBin "curl" ''
    set -euo pipefail

    socket=
    action=
    while (( $# > 0 )); do
      case $1 in
        --unix-socket)
          socket=$2
          shift 2
          ;;
        -d)
          action=$2
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done

    [[ -n $socket && -e $socket && -n $action ]] || exit 7
    printf '%s\n' "$action" >> "''${FAKE_CONTROL_LOG:?}"
    if [[ $action == accept || $action == cancel ]]; then
      [[ -z ''${FAKE_FOOT_GATE:-} ]] || : > "$FAKE_FOOT_GATE"
    fi
  '';

  fakeWlrctl = writeShellScriptBin "wlrctl" ''
    set -euo pipefail

    if [[ ''${1:-} == toplevel && ''${2:-} == list && ''${3:-} == state:inactive ]]; then
      list_count=0
      IFS= read -r list_count < "''${FAKE_LIST_COUNT:?}" || true
      ((list_count += 1))
      printf '%d\n' "$list_count" > "$FAKE_LIST_COUNT"

      source_file=''${FAKE_LIST_INITIAL:?}
      if (( list_count > 1 )) && [[ -n ''${FAKE_LIST_CURRENT:-} ]]; then
        source_file=$FAKE_LIST_CURRENT
      elif [[ -n ''${FAKE_LIST_CURRENT:-} && ''${FAKE_USE_CURRENT_FIRST:-0} == 1 ]]; then
        source_file=$FAKE_LIST_CURRENT
      fi
      ${coreutils}/bin/cat -- "$source_file"
      exit 0
    fi

    if [[ ''${1:-} == toplevel && ''${2:-} == focus && $# == 4 ]]; then
      printf '%s\t%s\n' "$3" "$4" >> "''${FAKE_FOCUS_LOG:?}"
      focus_count=0
      IFS= read -r focus_count < "''${FAKE_FOCUS_COUNT:?}" || true
      ((focus_count += 1))
      printf '%d\n' "$focus_count" > "$FAKE_FOCUS_COUNT"
      if [[ ''${FAKE_FAIL_FIRST_FOCUS:-0} == 1 && $focus_count == 1 ]]; then
        exit 1
      fi
      exit 0
    fi

    exit 2
  '';

  switcher = callPackage ../packages/labwc-window-switcher.nix {
    curl = fakeCurl;
    foot = fakeFoot;
    wlrctl = fakeWlrctl;
  };
in
runCommand "labwc-window-switcher-test" { nativeBuildInputs = [ coreutils ]; } ''
  set -euo pipefail

  chooser=${switcher}/bin/labwc-window-switcher
  test_root=$TMPDIR/window-switcher-tests

  new_run() {
    run_dir="$test_root/$1"
    mkdir -p "$run_dir/runtime"
    : > "$run_dir/initial"
    : > "$run_dir/current"
    : > "$run_dir/candidates"
    : > "$run_dir/foot-count"
    : > "$run_dir/focus-log"
    : > "$run_dir/control-log"
    : > "$run_dir/direction-log"
    printf '0\n' > "$run_dir/list-count"
    printf '0\n' > "$run_dir/focus-count"

    export XDG_RUNTIME_DIR=$run_dir/runtime
    export FAKE_WINDOW_EXPORT=$XDG_RUNTIME_DIR/labwc-window-switcher-windows
    export FAKE_LIST_INITIAL=$run_dir/initial
    export FAKE_LIST_CURRENT=$run_dir/current
    export FAKE_LIST_COUNT=$run_dir/list-count
    export FAKE_FOCUS_LOG=$run_dir/focus-log
    export FAKE_FOCUS_COUNT=$run_dir/focus-count
    export FAKE_FOOT_COUNT=$run_dir/foot-count
    export FAKE_CANDIDATES_SNAPSHOT=$run_dir/candidates
    export FAKE_CONTROL_LOG=$run_dir/control-log
    export FAKE_DIRECTION_LOG=$run_dir/direction-log
    export FAKE_SELECTION_LINE=1
    unset \
      FAKE_FAIL_FIRST_FOCUS \
      FAKE_FOOT_CANCEL \
      FAKE_FOOT_GATE \
      FAKE_USE_CURRENT_FIRST
  }

  write_window() {
    printf '%s\0%s\0%s\0%s\0%s\0' "$@" >> "$FAKE_WINDOW_EXPORT"
  }

  wait_for_file() {
    local path=$1
    for (( attempt = 0; attempt < 500; attempt++ )); do
      [[ ! -e $path ]] || return 0
      sleep 0.01
    done
    return 1
  }

  new_run normal
  write_window 10 1 1 foot current
  write_window 11 0 2 firefox 'Docs: API'
  write_window 12 0 3 foot project
  write_window 13 0 4 labwc-window-switcher stale
  "$chooser" next
  [[ $(<"$FAKE_FOCUS_LOG") == $'app_id:firefox\ttitle:Docs: API' ]]
  [[ $(<"$FAKE_CANDIDATES_SNAPSHOT") == $'11\t[2]  firefox  Docs: API\n12\t[3]  foot  project' ]]
  [[ $(<"$FAKE_DIRECTION_LOG") == next ]]
  [[ $(wc -l < "$FAKE_FOOT_COUNT") -eq 1 ]]
  [[ $(<"$FAKE_LIST_COUNT") -eq 0 ]]

  new_run empty
  write_window 20 1 1 foot current
  "$chooser" next
  [[ ! -s $FAKE_FOOT_COUNT ]]
  [[ ! -s $FAKE_FOCUS_LOG ]]

  new_run cancel
  write_window 30 0 2 firefox Browser
  export FAKE_FOOT_CANCEL=1
  "$chooser" next
  [[ $(wc -l < "$FAKE_FOOT_COUNT") -eq 1 ]]
  [[ ! -s $FAKE_FOCUS_LOG ]]

  new_run dynamic-title
  write_window 40 0 3 foot '[building] project'
  printf '%s\n' 'foot: [ready] project' > "$FAKE_LIST_CURRENT"
  export FAKE_FAIL_FIRST_FOCUS=1
  export FAKE_USE_CURRENT_FIRST=1
  "$chooser" next
  [[ $(<"$FAKE_FOCUS_LOG") == $'app_id:foot\ttitle:[building] project\napp_id:foot\ttitle:[ready] project' ]]
  [[ $(<"$FAKE_LIST_COUNT") -eq 1 ]]

  new_run fallback
  printf '%s\n' 'firefox: Browser' > "$FAKE_LIST_INITIAL"
  "$chooser" next
  [[ $(<"$FAKE_CANDIDATES_SNAPSHOT") == $'fallback-1\t[?]  firefox  Browser' ]]
  [[ $(<"$FAKE_FOCUS_LOG") == $'app_id:firefox\ttitle:Browser' ]]
  [[ $(<"$FAKE_LIST_COUNT") -eq 1 ]]

  new_run reverse
  write_window 50 0 1 firefox Browser
  write_window 51 0 4 foot Terminal
  export FAKE_SELECTION_LINE=2
  "$chooser" previous
  [[ $(<"$FAKE_DIRECTION_LOG") == previous ]]
  [[ $(<"$FAKE_FOCUS_LOG") == $'app_id:foot\ttitle:Terminal' ]]

  new_run repeated-cycle
  write_window 60 0 2 firefox Browser
  write_window 61 0 5 foot Terminal
  export FAKE_FOOT_GATE=$run_dir/release
  "$chooser" next & first_pid=$!
  wait_for_file "$FAKE_FOOT_GATE.opened"
  "$chooser" next
  "$chooser" previous
  "$chooser" accept
  wait "$first_pid"
  [[ $(wc -l < "$FAKE_FOOT_COUNT") -eq 1 ]]
  [[ $(<"$FAKE_CONTROL_LOG") == $'down\nup\naccept' ]]
  [[ $(<"$FAKE_FOCUS_LOG") == $'app_id:firefox\ttitle:Browser' ]]

  new_run quick-release
  write_window 70 0 6 foot Editor
  export FAKE_FOOT_GATE=$run_dir/release
  "$chooser" accept & accept_pid=$!
  wait_for_file "$XDG_RUNTIME_DIR/labwc-window-switcher"
  "$chooser" next & chooser_pid=$!
  wait "$accept_pid"
  wait "$chooser_pid"
  [[ $(<"$FAKE_CONTROL_LOG") == accept ]]
  [[ $(<"$FAKE_FOCUS_LOG") == $'app_id:foot\ttitle:Editor' ]]

  new_run stray-release
  "$chooser" accept
  [[ ! -s $FAKE_FOOT_COUNT ]]
  [[ ! -s $FAKE_CONTROL_LOG ]]

  touch "$out"
''
