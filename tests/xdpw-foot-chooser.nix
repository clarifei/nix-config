{
  coreutils,
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
      while [[ ! -e $FAKE_FOOT_GATE ]]; do
        sleep 0.01
      done
    fi
    sleep "''${FAKE_FOOT_DELAY:-0.25}"
    if [[ ''${FAKE_FOOT_CANCEL:-0} == 1 ]]; then
      exit 0
    fi
    head --lines=1 -- "$candidates" > "$selection"
  '';

  chooser = callPackage ../packages/xdpw-foot-chooser.nix { foot = fakeFoot; };
in
runCommand "xdpw-foot-chooser-test" { nativeBuildInputs = [ coreutils ]; } ''
  set -euo pipefail

  chooser=${chooser}/bin/xdpw-foot-chooser
  test_root=$TMPDIR/tests

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
  while [[ ! -s $run_dir/count ]]; do sleep 0.01; done
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
  while [[ ! -e $FAKE_FOOT_GATE.opened ]]; do sleep 0.01; done
  printf '%s\n' 'Window: Vesktop (window-1)' | "$chooser" > "$run_dir/out-2" & pid_two=$!
  while [[ ! -r $run_dir/runtime/xdpw-foot-chooser/sequence ]] \
    || (( $(<"$run_dir/runtime/xdpw-foot-chooser/sequence") < 2 )); do sleep 0.01; done
  printf '%s\n' 'Monitor: DP-1 Main' | "$chooser" > "$run_dir/out-3" & pid_three=$!
  while (( $(<"$run_dir/runtime/xdpw-foot-chooser/sequence") < 3 )); do sleep 0.01; done
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

  touch "$out"
''
