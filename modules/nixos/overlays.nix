{
  host,
  lib,
  nix-cachyos-kernel,
  ...
}:

{
  nixpkgs.overlays =
    lib.optional (host.system == "x86_64-linux") nix-cachyos-kernel.overlays.pinned
    ++ [
      (final: prev: {
        labwc = final.callPackage ../../packages/labwc {
          labwc = prev.labwc;
        };
        labwc-window-switcher = final.callPackage ../../packages/labwc-window-switcher { };
        vesktop = final.callPackage ../../packages/vesktop {
          vesktop = prev.vesktop;
        };
        xdg-desktop-portal-termfilechooser =
          final.callPackage ../../packages/xdg-desktop-portal-termfilechooser
            {
              xdg-desktop-portal-termfilechooser = prev.xdg-desktop-portal-termfilechooser;
            };
        xdg-desktop-portal-wlr = final.callPackage ../../packages/xdg-desktop-portal-wlr {
          xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr;
        };
        xdpw-foot-chooser = final.callPackage ../../packages/xdpw-foot-chooser { };
      })
    ];
}
