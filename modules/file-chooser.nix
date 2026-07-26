{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (_final: prev: {
      xdg-desktop-portal-termfilechooser = prev.xdg-desktop-portal-termfilechooser.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [ ./patches/termfilechooser-filters.patch ];
      });
    })
  ];

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-termfilechooser ];

    config = {
      labwc = {
        default = [
          "wlr"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = "termfilechooser";
        "org.freedesktop.impl.portal.Inhibit" = "none";
      };

      # Also cover sessions that identify themselves only as wlroots.
      wlroots."org.freedesktop.impl.portal.FileChooser" = "termfilechooser";
    };
  };
}
