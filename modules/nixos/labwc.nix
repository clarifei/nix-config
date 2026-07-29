{
  config,
  host,
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
    settings = {
      initial_session = {
        command = lib.getExe pkgs.labwc;
        user = host.username;
      };
      default_session = {
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
  };
}
