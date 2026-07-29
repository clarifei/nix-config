{
  lib,
  pkgs,
  ...
}:

let
  highestRefresh = pkgs.writeShellApplication {
    name = "wlr-randr-highest-refresh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.wlr-randr
    ];
    text = ''
      # ponytail: polling keeps this compositor-agnostic; use output events if needed.
      while sleep 3; do
        wlr-randr --json \
          | jq -r '
            .[]
            | select(.enabled)
            | . as $output
            | ($output.modes | map(.width * .height) | max) as $nativePixels
            | ($output.modes
              | map(select(.width * .height == $nativePixels))
              | max_by(.refresh)) as $maximum
            | ($output.modes | map(select(.current)) | first) as $current
            | select(
                ($current == null)
                or ($current.width * $current.height != $maximum.width * $maximum.height)
                or (($current.refresh + 0.01) < $maximum.refresh)
              )
            | [$output.name, "\($maximum.width)x\($maximum.height)@\($maximum.refresh)Hz"]
            | @tsv
          ' \
          | while IFS=$'\t' read -r output mode; do
              [[ -n $output && -n $mode ]] || continue
              wlr-randr --output "$output" --mode "$mode" || true
            done
      done
    '';
  };
in
{
  systemd.user.services.wlr-randr-highest-refresh = {
    Unit = {
      Description = "Use the highest native-resolution monitor refresh rate";
      After = [ "labwc-session.target" ];
      PartOf = [ "labwc-session.target" ];
    };
    Service = {
      ExecStart = lib.getExe highestRefresh;
      Restart = "always";
      RestartSec = 1;
    };
    Install.WantedBy = [ "labwc-session.target" ];
  };
}
