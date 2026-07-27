{ pkgs, ... }:

{
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
