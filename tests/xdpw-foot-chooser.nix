{
  coreutils,
  util-linux,
  runCommand,
  writeShellScriptBin,
  callPackage,
}:

let
  fakeFoot = writeShellScriptBin "foot" ''
    set -eu
    printf '%s\n' "$BASHPID" >> "''${FAKE_FOOT_COUNT:?}"
    while [[ $1 == --* ]]; do
      shift
    done
    candidates=$2
    selection=$3
    if [[ -n ''${FAKE_FOOT_GATE:-} && ! -e ''${FAKE_FOOT_GATE}.opened ]]; then
      : > "''${FAKE_FOOT_GATE}.opened"
      for (( attempt = 0; attempt < 500; attempt++ )); do
        [[ ! -e $FAKE_FOOT_GATE ]] || break
        sleep 0.01
      done
      [[ -e $FAKE_FOOT_GATE ]] || exit 124
    fi
    sleep "''${FAKE_FOOT_DELAY:-0.25}"
    if [[ ''${FAKE_FOOT_CANCEL:-0} == 1 ]]; then
      exit 0
    fi
    head --lines=1 -- "$candidates" > "$selection"
  '';

  chooser = callPackage ../packages/xdpw-foot-chooser.nix { foot = fakeFoot; };
in
runCommand "xdpw-foot-chooser-test" {
  nativeBuildInputs = [
    coreutils
    util-linux
  ];
} ''
  set -euo pipefail

  chooser=${chooser}/bin/xdpw-foot-chooser
  test_root=$TMPDIR/tests

  path_exists() {
    [[ -e $1 ]]
  }

  path_nonempty() {
    [[ -s $1 ]]
  }

  sequence_at_least() {
    local sequence_file=$1
    local expected=$2
    local sequence=0
    [[ -r $sequence_file ]] || return 1
    IFS= read -r sequence < "$sequence_file" || true
    [[ $sequence =~ ^[0-9]+$ ]] && (( sequence >= expected ))
  }

  wait_until() {
    local description=$1
    shift
    local attempt
    for (( attempt = 0; attempt < 500; attempt++ )); do
      if "$@"; then
        return 0
      fi
      sleep 0.01
    done
    echo "timed out waiting for $description" >&2
    return 1
  }

  run_dir=$test_root/same
  mkdir -p "$run_dir/runtime"
  : > "$run_dir/count"
  export XDG_RUNTIME_DIR=$run_dir/runtime
  export FAKE_FOOT_COUNT=$run_dir/count
  export FAKE_FOOT_DELAY=0.4
  unset FAKE_FOOT_CANCEL || true
  printf '%s\n' 'Monitor: DP-1 Main' | "$chooser" > "$run_dir/out-1" & pid_one=$!
  printf '%s\n' 'Monitor: DP-1 Main' | "$chooser" > "$run_dir/out-2" & pid_two=$!
  wait "$pid_one"
  wait "$pid_two"
  [[ $(<"$run_dir/out-1") == 'Monitor: DP-1 Main' ]]
  [[ $(<"$run_dir/out-2") == 'Monitor: DP-1 Main' ]]
  [[ $(wc -l < "$run_dir/count") -eq 1 ]]
  printf '%s\n' 'Monitor: DP-1 Main' | "$chooser" > "$run_dir/out-3"
  [[ $(wc -l < "$run_dir/count") -eq 2 ]]

  # Titles can change while overlapping portal requests are queued. The stable identifier keeps
  # both requests in one transaction, while each caller receives a label valid for its own list.
  run_dir=$test_root/dynamic-title
  mkdir -p "$run_dir/runtime"
  : > "$run_dir/count"
  export XDG_RUNTIME_DIR=$run_dir/runtime
  export FAKE_FOOT_COUNT=$run_dir/count
  export FAKE_FOOT_DELAY=0.4
  printf '%s\n' 'Window: Building (window-1)' | "$chooser" > "$run_dir/out-1" & pid_one=$!
  wait_until "dynamic-title chooser" path_nonempty "$run_dir/count"
  printf '%s\n' 'Window: Ready (window-1)' | "$chooser" > "$run_dir/out-2" & pid_two=$!
  wait "$pid_one"
  wait "$pid_two"
  [[ $(<"$run_dir/out-1") == 'Window: Building (window-1)' ]]
  [[ $(<"$run_dir/out-2") == 'Window: Ready (window-1)' ]]
  [[ $(wc -l < "$run_dir/count") -eq 1 ]]

  run_dir=$test_root/different
  mkdir -p "$run_dir/runtime"
  : > "$run_dir/count"
  export XDG_RUNTIME_DIR=$run_dir/runtime
  export FAKE_FOOT_COUNT=$run_dir/count
  printf '%s\n' 'Monitor: DP-1 Main' | "$chooser" > "$run_dir/out-1" & pid_one=$!
  printf '%s\n' 'Window: Vesktop (window-1)' | "$chooser" > "$run_dir/out-2" & pid_two=$!
  wait "$pid_one"
  wait "$pid_two"
  [[ $(<"$run_dir/out-1") == 'Monitor: DP-1 Main' ]]
  [[ $(<"$run_dir/out-2") == 'Window: Vesktop (window-1)' ]]
  [[ $(wc -l < "$run_dir/count") -eq 2 ]]

  # Keep the first UI open while A, B, A requests receive ordered tickets. The B result must not
  # overwrite the first A transaction before the final A waiter consumes it.
  run_dir=$test_root/interleaved
  mkdir -p "$run_dir/runtime"
  : > "$run_dir/count"
  export XDG_RUNTIME_DIR=$run_dir/runtime
  export FAKE_FOOT_COUNT=$run_dir/count
  export FAKE_FOOT_DELAY=0.05
  export FAKE_FOOT_GATE=$run_dir/release
  printf '%s\n' 'Monitor: DP-1 Main' | "$chooser" > "$run_dir/out-1" & pid_one=$!
  wait_until "interleaved chooser gate" path_exists "$FAKE_FOOT_GATE.opened"
  printf '%s\n' 'Window: Vesktop (window-1)' | "$chooser" > "$run_dir/out-2" & pid_two=$!
  sequence_file=$run_dir/runtime/xdpw-foot-chooser/sequence
  wait_until "second interleaved ticket" sequence_at_least "$sequence_file" 2
  printf '%s\n' 'Monitor: DP-1 Main' | "$chooser" > "$run_dir/out-3" & pid_three=$!
  wait_until "third interleaved ticket" sequence_at_least "$sequence_file" 3
  touch "$FAKE_FOOT_GATE"
  wait "$pid_one"
  wait "$pid_two"
  wait "$pid_three"
  [[ $(<"$run_dir/out-1") == 'Monitor: DP-1 Main' ]]
  [[ $(<"$run_dir/out-2") == 'Window: Vesktop (window-1)' ]]
  [[ $(<"$run_dir/out-3") == 'Monitor: DP-1 Main' ]]
  [[ $(wc -l < "$run_dir/count") -eq 2 ]]
  unset FAKE_FOOT_GATE

  run_dir=$test_root/cancel
  mkdir -p "$run_dir/runtime"
  : > "$run_dir/count"
  export XDG_RUNTIME_DIR=$run_dir/runtime
  export FAKE_FOOT_COUNT=$run_dir/count
  export FAKE_FOOT_CANCEL=1
  printf '%s\n' 'Monitor: DP-1 Main' | "$chooser" > "$run_dir/out-1" & pid_one=$!
  printf '%s\n' 'Monitor: DP-1 Main' | "$chooser" > "$run_dir/out-2" & pid_two=$!
  wait "$pid_one"
  wait "$pid_two"
  [[ ! -s "$run_dir/out-1" ]]
  [[ ! -s "$run_dir/out-2" ]]
  [[ $(wc -l < "$run_dir/count") -eq 1 ]]
  unset FAKE_FOOT_CANCEL
  printf '%s\n' 'Monitor: DP-1 Main' | "$chooser" > "$run_dir/out-3"
  [[ $(<"$run_dir/out-3") == 'Monitor: DP-1 Main' ]]
  [[ $(wc -l < "$run_dir/count") -eq 2 ]]

  # SIGKILL bypasses EXIT traps. The next request must recognize the unlocked marker as stale so
  # it cannot pin old transaction results for the remainder of the login session.
  run_dir=$test_root/stale-pending
  mkdir -p "$run_dir/runtime/xdpw-foot-chooser"
  : > "$run_dir/count"
  export XDG_RUNTIME_DIR=$run_dir/runtime
  export FAKE_FOOT_COUNT=$run_dir/count
  export FAKE_FOOT_DELAY=0.05
  unset FAKE_FOOT_CANCEL FAKE_FOOT_GATE || true
  exec {ui_hold_fd}> "$run_dir/runtime/xdpw-foot-chooser/ui.lock"
  flock --exclusive "$ui_hold_fd"
  printf '%s\n' 'Monitor: DP-1 Main' | "$chooser" > "$run_dir/killed-out" & killed_pid=$!
  pending_dir=$run_dir/runtime/xdpw-foot-chooser/pending
  wait_until "killed request marker" path_exists "$pending_dir/1"
  kill -KILL "$killed_pid"
  killed_status=0
  wait "$killed_pid" || killed_status=$?
  [[ $killed_status -eq 137 ]]
  results_dir=$run_dir/runtime/xdpw-foot-chooser/results
  stale_result=$results_dir/stale.1.result
  printf '%s\n' 1 1 cancelled > "$stale_result"
  flock --unlock "$ui_hold_fd"
  exec {ui_hold_fd}>&-
  printf '%s\n' 'Monitor: DP-1 Main' | "$chooser" > "$run_dir/out"
  [[ $(<"$run_dir/out") == 'Monitor: DP-1 Main' ]]
  [[ ! -e $pending_dir/1 ]]
  [[ ! -e $stale_result ]]

  touch "$out"
''
