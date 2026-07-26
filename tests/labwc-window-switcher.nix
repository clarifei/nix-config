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
    (( $# == 3 ))
    candidates=$2
    selection=$3

    ${coreutils}/bin/cp -- "$candidates" "''${FAKE_CANDIDATES_SNAPSHOT:?}"
    if [[ -n ''${FAKE_FOOT_GATE:-} ]]; then
      : > "''${FAKE_FOOT_GATE}.opened"
      while [[ ! -e $FAKE_FOOT_GATE ]]; do
        ${coreutils}/bin/sleep 0.01
      done
    fi
    [[ ''${FAKE_FOOT_CANCEL:-0} != 1 ]] || exit 0
    ${gnused}/bin/sed -n "''${FAKE_SELECTION_LINE:-1}p" "$candidates" > "$selection"
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
    printf '0\n' > "$run_dir/list-count"
    printf '0\n' > "$run_dir/focus-count"

    export XDG_RUNTIME_DIR=$run_dir/runtime
    export FAKE_LIST_INITIAL=$run_dir/initial
    export FAKE_LIST_CURRENT=$run_dir/current
    export FAKE_LIST_COUNT=$run_dir/list-count
    export FAKE_FOCUS_LOG=$run_dir/focus-log
    export FAKE_FOCUS_COUNT=$run_dir/focus-count
    export FAKE_FOOT_COUNT=$run_dir/foot-count
    export FAKE_CANDIDATES_SNAPSHOT=$run_dir/candidates
    export FAKE_SELECTION_LINE=1
    unset FAKE_FAIL_FIRST_FOCUS FAKE_FOOT_CANCEL FAKE_FOOT_GATE
  }

  new_run normal
  printf '%s\n' \
    'foot: project' \
    'labwc-window-switcher: stale chooser' \
    'firefox: Docs: API' > "$FAKE_LIST_INITIAL"
  export FAKE_SELECTION_LINE=2
  "$chooser"
  [[ $(<"$FAKE_FOCUS_LOG") == $'app_id:firefox\ttitle:Docs: API' ]]
  [[ $(<"$FAKE_CANDIDATES_SNAPSHOT") == $'1\tfoot: project\n2\tfirefox: Docs: API' ]]
  [[ $(wc -l < "$FAKE_FOOT_COUNT") -eq 1 ]]

  new_run empty
  "$chooser"
  [[ ! -s $FAKE_FOOT_COUNT ]]
  [[ ! -s $FAKE_FOCUS_LOG ]]

  new_run cancel
  printf '%s\n' 'firefox: Browser' > "$FAKE_LIST_INITIAL"
  export FAKE_FOOT_CANCEL=1
  "$chooser"
  [[ $(wc -l < "$FAKE_FOOT_COUNT") -eq 1 ]]
  [[ ! -s $FAKE_FOCUS_LOG ]]

  new_run dynamic-title
  printf '%s\n' 'foot: [building] project' > "$FAKE_LIST_INITIAL"
  printf '%s\n' 'foot: [ready] project' > "$FAKE_LIST_CURRENT"
  export FAKE_FAIL_FIRST_FOCUS=1
  "$chooser"
  [[ $(<"$FAKE_FOCUS_LOG") == $'app_id:foot\ttitle:[building] project\napp_id:foot\ttitle:[ready] project' ]]
  [[ $(<"$FAKE_LIST_COUNT") -eq 2 ]]

  new_run single-instance
  printf '%s\n' 'firefox: Browser' > "$FAKE_LIST_INITIAL"
  export FAKE_FOOT_GATE=$run_dir/release
  "$chooser" & first_pid=$!
  while [[ ! -e $FAKE_FOOT_GATE.opened ]]; do sleep 0.01; done
  "$chooser"
  touch "$FAKE_FOOT_GATE"
  wait "$first_pid"
  [[ $(wc -l < "$FAKE_FOOT_COUNT") -eq 1 ]]
  [[ $(wc -l < "$FAKE_FOCUS_LOG") -eq 1 ]]
  [[ $(<"$FAKE_LIST_COUNT") -eq 1 ]]

  touch "$out"
''
