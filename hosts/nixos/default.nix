{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/file-chooser.nix
    ../../modules/nixos/home-manager.nix
    ../../modules/nixos/kernel.nix
    ../../modules/nixos/labwc.nix
    ../../modules/nixos/nix.nix
    ../../modules/nixos/noctalia.nix
    ../../modules/nixos/screen-sharing.nix
    ../../modules/nixos/swap.nix
    ../../modules/nixos/system.nix
  ];

  system.stateVersion = "26.05";
}
