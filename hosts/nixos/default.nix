{ host, lib, ... }:

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
    ../../modules/nixos/overlays.nix
    ../../modules/nixos/screen-sharing.nix
    ../../modules/nixos/swap.nix
    ../../modules/nixos/system.nix
  ]
  ++ lib.optional ((host.graphics or null) == "nvidia") ./graphics.nix;

  nixpkgs.hostPlatform = host.system;
  system.stateVersion = host.stateVersion;
}
