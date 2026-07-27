{ lib, pkgs, ... }:

{
  xdg.portal.wlr.settings.screencast = {
    chooser_type = "dmenu";
    chooser_cmd = lib.getExe pkgs.xdpw-foot-chooser;
    max_fps = 60;
  };

  systemd.user.services.xdg-desktop-portal-wlr.environment.XDPW_PERSIST_MODE = "transient";
}
