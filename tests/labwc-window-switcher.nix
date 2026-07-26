{
  callPackage,
  coreutils,
  gnused,
  runCommand,
  util-linux,
  writeShellScriptBin,
}:

let
  fakeFoot = writeShellScriptBin "foot" ''
    set -euo pipefail

    printf '%s\n' "''${LABWC_WINDOW_SWITCHER_GENERATION:?}" >> "''${FAKE_FOOT_COUNT:?}"
    foot_run_count=$(${coreutils}/bin/wc -l < "$FAKE_FOOT_COUNT")
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

    if [[ -n ''${FAKE_FOOT_PRE_SOCKET_GATE:-} && $foot_run_count == 1 ]]; then
      : > "$FAKE_FOOT_PRE_SOCKET_GATE.opened"
      gate_open=0
      for (( attempt = 0; attempt < 500; attempt++ )); do
        if [[ -e $FAKE_FOOT_PRE_SOCKET_GATE ]]; then
          gate_open=1
          break
        fi
        ${coreutils}/bin/sleep 0.01
      done
      (( gate_open == 1 ))
    fi

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
    if [[ -n ''${FAKE_CURL_GATE:-} ]]; then
      : > "$FAKE_CURL_GATE.opened"
      gate_open=0
      for (( attempt = 0; attempt < 500; attempt++ )); do
        if [[ -e $FAKE_CURL_GATE ]]; then
          gate_open=1
          break
        fi
        ${coreutils}/bin/sleep 0.01
      done
      (( gate_open == 1 ))
    fi
    [[ -e $socket ]] || exit 7
    socket_state=
    IFS= read -r socket_state < "$socket" || true
    [[ $socket_state != stale ]] || exit 7
    printf '%s\t%s\n' "''${LABWC_WINDOW_SWITCHER_GENERATION:?}" "$action" \
      >> "''${FAKE_CONTROL_LOG:?}"
    if [[ $action == accept || $action == cancel ]]; then
      [[ -z ''${FAKE_FOOT_GATE:-} ]] || : > "$FAKE_FOOT_GATE"
    fi
  '';

  fakeSignal = writeShellScriptBin "kill" ''
    set -euo pipefail

    (( $# == 3 ))
    [[ $1 == -USR1 && $2 == -- ]]
    [[ $3 == "''${FAKE_LABWC_PID:?}:''${FAKE_LABWC_PIDFD_INODE:?}" ]]
    generation=''${LABWC_WINDOW_SWITCHER_GENERATION:?}
    focus_file="''${XDG_RUNTIME_DIR:?}/labwc-window-switcher-focus.$generation"
    [[ -f $focus_file && -O $focus_file ]]

    current_generation=
    IFS= read -r current_generation < "''${FAKE_CURRENT_GENERATION_FILE:?}"
    [[ $generation == "$current_generation" ]] || exit 0

    if [[ ''${FAKE_FOCUS_REJECT:-0} == 1 ]]; then
      : > "$focus_file"
      exit 0
    fi

    selection_id=
    IFS= read -r selection_id < "$focus_file"
    ${coreutils}/bin/rm -f -- "$focus_file"
    printf '%s\t%s\n' "$generation" "$selection_id" >> "''${FAKE_FOCUS_LOG:?}"
  '';

  switcher = callPackage ../packages/labwc-window-switcher.nix {
    curl = fakeCurl;
    foot = fakeFoot;
    focusSignal = "${fakeSignal}/bin/kill";
  };
in
runCommand "labwc-window-switcher-test" { nativeBuildInputs = [ util-linux ]; } ''
  set -euo pipefail

  chooser=${switcher}/bin/labwc-window-switcher
  test_root=$TMPDIR/window-switcher-tests

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

  new_generation() {
    ((generation_counter += 1))
    export LABWC_WINDOW_SWITCHER_GENERATION="$LABWC_PID-$LABWC_START_TIME-$FAKE_LABWC_PIDFD_INODE-$generation_counter"
    printf '%s\n' "$LABWC_WINDOW_SWITCHER_GENERATION" > "$FAKE_CURRENT_GENERATION_FILE"
    export FAKE_WINDOW_EXPORT="$XDG_RUNTIME_DIR/labwc-window-switcher-windows.$LABWC_WINDOW_SWITCHER_GENERATION"
  }

  new_run() {
    run_dir="$test_root/$1"
    mkdir -p "$run_dir/runtime"
    : > "$run_dir/candidates"
    : > "$run_dir/foot-count"
    : > "$run_dir/focus-log"
    : > "$run_dir/control-log"
    : > "$run_dir/direction-log"

    export XDG_RUNTIME_DIR=$run_dir/runtime
    export LABWC_PID=$BASHPID
    export LABWC_START_TIME
    LABWC_START_TIME=$(process_start_time "$LABWC_PID")
    export FAKE_LABWC_PID=$LABWC_PID
    export FAKE_LABWC_PIDFD_INODE=1
    export FAKE_CURRENT_GENERATION_FILE=$run_dir/current-generation
    export FAKE_FOCUS_LOG=$run_dir/focus-log
    export FAKE_FOOT_COUNT=$run_dir/foot-count
    export FAKE_CANDIDATES_SNAPSHOT=$run_dir/candidates
    export FAKE_CONTROL_LOG=$run_dir/control-log
    export FAKE_DIRECTION_LOG=$run_dir/direction-log
    export FAKE_SELECTION_LINE=1
    generation_counter=0
    new_generation
    unset \
      FAKE_CURL_GATE \
      FAKE_FOCUS_REJECT \
      FAKE_FOOT_CANCEL \
      FAKE_FOOT_GATE \
      FAKE_FOOT_PRE_SOCKET_GATE
  }

  state_dir() {
    printf '%s/labwc-window-switcher/%s\n' \
      "$XDG_RUNTIME_DIR" "$LABWC_WINDOW_SWITCHER_GENERATION"
  }

  switcher_lock() {
    printf '%s/labwc-window-switcher/lock.%s\n' \
      "$XDG_RUNTIME_DIR" "$LABWC_WINDOW_SWITCHER_GENERATION"
  }

  write_window_to() {
    local path=$1
    shift
    printf '%s\0%s\0%s\0%s\0%s\0' "$@" >> "$path"
  }

  write_window() {
    write_window_to "$FAKE_WINDOW_EXPORT" "$@"
  }

  wait_for_file() {
    local path=$1
    for (( attempt = 0; attempt < 500; attempt++ )); do
      [[ ! -e $path ]] || return 0
      sleep 0.01
    done
    return 1
  }

  wait_for_content() {
    local path=$1
    for (( attempt = 0; attempt < 500; attempt++ )); do
      [[ ! -s $path ]] || return 0
      sleep 0.01
    done
    return 1
  }

  process_exited() {
    ! kill -0 "$1" 2>/dev/null
  }

  expect_focus() {
    [[ $(<"$FAKE_FOCUS_LOG") == "$LABWC_WINDOW_SWITCHER_GENERATION"$'\t'"$1" ]]
  }

  new_run normal
  normal_state=$(state_dir)
  normal_lock=$(switcher_lock)
  write_window 10 1 1 foot current
  write_window 11 0 $'2\a' $'fire\bfox' $'Docs:\vAPI\177'
  write_window 12 0 3 foot project
  write_window 13 0 4 labwc-window-switcher stale
  "$chooser" next
  expect_focus 11
  [[ $(<"$FAKE_CANDIDATES_SNAPSHOT") == $'11\t[2 ]  fire fox  Docs: API \n12\t[3]  foot  project' ]]
  [[ $(<"$FAKE_DIRECTION_LOG") == next ]]
  [[ $(wc -l < "$FAKE_FOOT_COUNT") -eq 1 ]]
  [[ ! -e $normal_state && -f $normal_lock ]]

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
  "$chooser" next
  expect_focus 40

  new_run rejected-focus
  write_window 41 0 3 foot Closed
  export FAKE_FOCUS_REJECT=1
  if "$chooser" next; then
    exit 1
  fi
  [[ ! -s $FAKE_FOCUS_LOG ]]

  new_run missing-export
  "$chooser" next
  [[ ! -s $FAKE_FOOT_COUNT ]]
  [[ ! -s $FAKE_FOCUS_LOG ]]

  new_run stray-release
  stray_state=$(state_dir)
  stray_lock=$(switcher_lock)
  "$chooser" accept
  [[ ! -e $stray_state && ! -e $stray_lock ]]

  new_run stale-labwc-identity
  LABWC_WINDOW_SWITCHER_GENERATION="$LABWC_PID-$((LABWC_START_TIME + 1))-$FAKE_LABWC_PIDFD_INODE-1"
  export LABWC_WINDOW_SWITCHER_GENERATION
  export FAKE_WINDOW_EXPORT="$XDG_RUNTIME_DIR/labwc-window-switcher-windows.$LABWC_WINDOW_SWITCHER_GENERATION"
  write_window 45 0 3 foot Stale
  "$chooser" next
  [[ ! -s $FAKE_FOOT_COUNT ]]
  [[ ! -s $FAKE_FOCUS_LOG ]]

  new_run reverse
  write_window 50 0 1 firefox Browser
  write_window 51 0 4 foot Terminal
  export FAKE_SELECTION_LINE=2
  "$chooser" previous
  [[ $(<"$FAKE_DIRECTION_LOG") == previous ]]
  expect_focus 51

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
  expected_generation=$LABWC_WINDOW_SWITCHER_GENERATION
  [[ $(<"$FAKE_CONTROL_LOG") == "$expected_generation"$'\tdown\n'"$expected_generation"$'\tup\n'"$expected_generation"$'\taccept' ]]
  expect_focus 60

  new_run simultaneous-start
  current_state=$(state_dir)
  mkdir -p "$current_state"
  current_lock=$(switcher_lock)
  exec {startup_gate_fd}> "$current_lock"
  flock "$startup_gate_fd"
  write_window 63 0 5 foot Terminal
  export FAKE_FOOT_GATE=$run_dir/release
  "$chooser" next {startup_gate_fd}>&- & simultaneous_first_pid=$!
  "$chooser" next {startup_gate_fd}>&- & simultaneous_second_pid=$!
  sleep 0.05
  flock --unlock "$startup_gate_fd"
  exec {startup_gate_fd}>&-
  wait_for_file "$FAKE_FOOT_GATE.opened"
  wait_for_content "$FAKE_CONTROL_LOG"
  [[ $(<"$FAKE_CONTROL_LOG") == "$LABWC_WINDOW_SWITCHER_GENERATION"$'\tdown' ]]
  touch "$FAKE_FOOT_GATE"
  wait "$simultaneous_first_pid"
  wait "$simultaneous_second_pid"
  [[ $(wc -l < "$FAKE_FOOT_COUNT") -eq 1 ]]
  expect_focus 63

  new_run clean-owner-no-takeover
  write_window 65 0 5 foot Terminal
  export FAKE_FOOT_GATE=$run_dir/owner
  export FAKE_CURL_GATE=$run_dir/curl
  "$chooser" next & clean_owner_pid=$!
  wait_for_file "$FAKE_FOOT_GATE.opened"
  "$chooser" next & late_contender_pid=$!
  wait_for_file "$FAKE_CURL_GATE.opened"
  touch "$FAKE_FOOT_GATE"
  wait "$clean_owner_pid"
  touch "$FAKE_CURL_GATE"
  wait "$late_contender_pid"
  [[ $(wc -l < "$FAKE_FOOT_COUNT") -eq 1 ]]
  expect_focus 65

  new_run quick-release
  write_window 70 0 6 foot Editor
  export FAKE_FOOT_GATE=$run_dir/release
  "$chooser" accept & accept_pid=$!
  sleep 0.05
  "$chooser" next & next_pid=$!
  wait "$accept_pid"
  wait "$next_pid"
  [[ $(<"$FAKE_CONTROL_LOG") == "$LABWC_WINDOW_SWITCHER_GENERATION"$'\taccept' ]]
  expect_focus 70

  new_run stale-state
  current_state=$(state_dir)
  stale_session=$current_state/session.stale
  mkdir -p "$stale_session"
  printf '%s\n' stale > "$current_state/fzf.sock"
  : > "$current_state/running"
  : > "$stale_session/windows"
  : > "$stale_session/candidates"
  : > "$stale_session/selection"
  write_window 80 0 7 foot Recovered
  "$chooser" next
  expect_focus 80
  [[ ! -e $stale_session ]]
  [[ ! -e $current_state/running ]]
  [[ ! -e $current_state/fzf.sock ]]

  new_run stale-release
  current_state=$(state_dir)
  stale_session=$current_state/session.stale
  mkdir -p "$stale_session"
  printf '%s\n' stale > "$current_state/fzf.sock"
  : > "$current_state/running"
  : > "$FAKE_WINDOW_EXPORT"
  : > "$stale_session/windows"
  timeout 4 "$chooser" accept
  [[ ! -e $stale_session ]]
  [[ ! -e $FAKE_WINDOW_EXPORT ]]
  [[ ! -e $current_state/running ]]
  [[ ! -e $current_state/fzf.sock ]]

  new_run cross-generation-release
  old_generation=$LABWC_WINDOW_SWITCHER_GENERATION
  old_state=$(state_dir)
  mkdir -p "$old_state"
  : > "$old_state/running"
  old_lock=$(switcher_lock)
  exec {old_lock_fd}> "$old_lock"
  flock "$old_lock_fd"
  "$chooser" accept {old_lock_fd}>&- & old_release_pid=$!
  sleep 0.05
  new_generation
  write_window 86 0 9 foot Fresh
  export FAKE_FOOT_GATE=$run_dir/fresh-release
  "$chooser" next & fresh_owner_pid=$!
  wait_for_file "$FAKE_FOOT_GATE.opened"
  [[ ! -s $FAKE_CONTROL_LOG ]]
  flock --unlock "$old_lock_fd"
  exec {old_lock_fd}>&-
  wait "$old_release_pid"
  [[ ! -s $FAKE_CONTROL_LOG ]]
  touch "$FAKE_FOOT_GATE"
  wait "$fresh_owner_pid"
  expect_focus 86

  new_run fast-new-generation
  old_generation=$LABWC_WINDOW_SWITCHER_GENERATION
  write_window 87 0 8 foot Old
  export FAKE_FOOT_GATE=$run_dir/old-release
  "$chooser" next & old_owner_pid=$!
  wait_for_file "$FAKE_FOOT_GATE.opened"
  new_generation
  unset FAKE_FOOT_GATE
  write_window 88 0 9 foot Fresh
  "$chooser" next
  expect_focus 88
  touch "$run_dir/old-release"
  old_status=0
  wait "$old_owner_pid" || old_status=$?
  [[ $old_status -eq 1 ]]
  expect_focus 88
  [[ $(wc -l < "$FAKE_FOOT_COUNT") -eq 2 ]]

  new_run killed-wrapper
  write_window 90 0 8 foot Interrupted
  export FAKE_FOOT_GATE=$run_dir/release
  "$chooser" next & killed_wrapper_pid=$!
  wait_for_file "$FAKE_FOOT_GATE.opened"
  current_state=$(state_dir)
  wait_for_file "$current_state/foot.pid"
  read -r killed_foot_pid killed_foot_start < "$current_state/foot.pid"
  [[ $(process_start_time "$killed_foot_pid") == "$killed_foot_start" ]]
  kill -KILL "$killed_wrapper_pid"
  killed_status=0
  wait "$killed_wrapper_pid" || killed_status=$?
  [[ $killed_status -eq 137 ]]
  "$chooser" accept
  for (( attempt = 0; attempt < 500; attempt++ )); do
    process_exited "$killed_foot_pid" && break
    sleep 0.01
  done
  process_exited "$killed_foot_pid"
  [[ ! -e $current_state/foot.pid ]]
  [[ ! -s $FAKE_FOCUS_LOG ]]

  new_run owner-takeover
  write_window 95 0 8 foot Recovered
  export FAKE_FOOT_PRE_SOCKET_GATE=$run_dir/pre-socket
  "$chooser" next & abandoned_owner_pid=$!
  wait_for_file "$FAKE_FOOT_PRE_SOCKET_GATE.opened"
  current_state=$(state_dir)
  wait_for_file "$current_state/foot.pid"
  read -r abandoned_foot_pid abandoned_foot_start < "$current_state/foot.pid"
  [[ $(process_start_time "$abandoned_foot_pid") == "$abandoned_foot_start" ]]
  kill -KILL "$abandoned_owner_pid"
  abandoned_status=0
  wait "$abandoned_owner_pid" || abandoned_status=$?
  [[ $abandoned_status -eq 137 ]]
  unset FAKE_FOOT_PRE_SOCKET_GATE
  "$chooser" next
  expect_focus 95
  [[ $(wc -l < "$FAKE_FOOT_COUNT") -eq 2 ]]
  process_exited "$abandoned_foot_pid"

  new_run socket-owner-takeover
  write_window 96 0 8 foot Recovered
  export FAKE_FOOT_GATE=$run_dir/orphan-foot
  "$chooser" next & socket_owner_pid=$!
  wait_for_file "$FAKE_FOOT_GATE.opened"
  current_state=$(state_dir)
  read -r first_foot_pid first_foot_start < "$current_state/foot.pid"
  [[ $(process_start_time "$first_foot_pid") == "$first_foot_start" ]]
  kill -KILL "$socket_owner_pid"
  socket_owner_status=0
  wait "$socket_owner_pid" || socket_owner_status=$?
  [[ $socket_owner_status -eq 137 ]]
  unset FAKE_FOOT_GATE
  "$chooser" next
  [[ $(wc -l < "$FAKE_FOOT_COUNT") -eq 2 ]]
  [[ $(<"$FAKE_CONTROL_LOG") == "$LABWC_WINDOW_SWITCHER_GENERATION"$'\tcancel' ]]
  expect_focus 96
  process_exited "$first_foot_pid"

  new_run duplicate-record
  write_window 100 0 2 firefox Browser
  write_window 101 0 3 firefox Browser
  export FAKE_SELECTION_LINE=2
  "$chooser" next
  expect_focus 101

  touch "$out"
''
