{
  imports = [
    ./hardware-configuration.nix
    ./modules/desktop.nix
    ./modules/file-chooser.nix
    ./modules/home-manager.nix
    ./modules/kernel.nix
    ./modules/labwc.nix
    ./modules/nix.nix
    ./modules/noctalia.nix
    ./modules/swap.nix
    ./modules/system.nix
  ];

  system.stateVersion = "26.05";
}
