{ lib, pkgs, ... }:

let
  chooser = pkgs.callPackage ../../packages/xdpw-foot-chooser { };
in
{
  nixpkgs.overlays = [
    (_final: prev: {
      vesktop = prev.callPackage ../../packages/vesktop {
        vesktop = prev.vesktop;
      };
      xdg-desktop-portal-wlr = prev.callPackage ../../packages/xdg-desktop-portal-wlr {
        xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr;
      };
    })
  ];

  xdg.portal.wlr.settings.screencast = {
    chooser_type = "dmenu";
    chooser_cmd = lib.getExe chooser;
    max_fps = 60;
  };

  systemd.user.services.xdg-desktop-portal-wlr.environment.XDPW_PERSIST_MODE = "transient";
}
