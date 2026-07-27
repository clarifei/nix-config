{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.labwc = {
    enable = true;
    package = pkgs.labwc;
  };

  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session = {
      command = lib.concatStringsSep " " [
        (lib.getExe pkgs.tuigreet)
        "--time"
        "--remember"
        "--remember-session"
        "--asterisks"
        "--sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
        "--cmd labwc"
      ];
      user = "greeter";
    };
  };
}
