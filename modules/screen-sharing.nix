{ lib, pkgs, ... }:

let
  chooser = pkgs.callPackage ../packages/xdpw-foot-chooser.nix { };
in
{
  nixpkgs.overlays = [
    (_final: prev: {
      vesktop =
        # Electron 42 times out delegated PipeWire source lists after three seconds, before
        # the portal chooser has necessarily completed. Electron 41 waits for the delegated
        # selection event; Electron 43 has the equivalent upstream fix but is not packaged yet.
        (prev.vesktop.override { electron_42 = prev.electron_41; }).overrideAttrs (oldAttrs: {
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
