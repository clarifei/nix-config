{ lib, pkgs, ... }:

let
  chooser = pkgs.callPackage ../packages/xdpw-foot-chooser.nix { };
in
{
  nixpkgs.overlays = [
    (_final: prev: {
      vesktop = prev.callPackage ../packages/vesktop.nix {
        vesktop = prev.vesktop;
      };
      xdg-desktop-portal-wlr = prev.callPackage ../packages/xdg-desktop-portal-wlr.nix {
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
