{
  imports = [
    ./kanshi.nix
    ./labwc.nix
    ./noctalia
  ];

  xdg.enable = true;
  wayland.systemd.target = "labwc-session.target";
}
