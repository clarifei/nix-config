{ pkgs, ... }:

{
  imports = [
    ./labwc.nix
    ./noctalia
  ];

  home.pointerCursor = {
    name = "Bibata-Original-Ice";
    package = pkgs.bibata-cursors;
    gtk.enable = true;
    x11.enable = true;
  };

  xdg.enable = true;
  wayland.systemd.target = "labwc-session.target";
}
