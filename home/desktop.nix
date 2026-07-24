{
  imports = [
    ./desktop/kanshi.nix
    ./desktop/labwc.nix
    ./desktop/noctalia.nix
  ];

  xdg.enable = true;
  wayland.systemd.target = "labwc-session.target";
}
