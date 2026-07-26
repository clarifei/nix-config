{ lib, pkgs, ... }:

let
  chooser = pkgs.callPackage ../packages/xdpw-foot-chooser.nix { };
in
{
  nixpkgs.overlays = [
    (_final: prev: {
      vesktop = prev.vesktop.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [
          ./patches/vesktop-screen-share-transaction.patch
          ./patches/vesktop-square-splash.patch
        ];
      });

      xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [ ./patches/xdpw-window-restore.patch ];
      });
    })
  ];

  xdg.portal.wlr.settings.screencast = {
    chooser_type = "dmenu";
    chooser_cmd = lib.getExe chooser;
    max_fps = 60;
  };

  systemd.user.services.xdg-desktop-portal-wlr.environment.XDPW_PERSIST_MODE = "transient";
}
