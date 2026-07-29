{
  imports = [
    ./labwc.nix
    ./noctalia
    ./refresh-rate.nix
  ];

  xdg.enable = true;
  wayland.systemd.target = "labwc-session.target";
}
