{ noctalia, pkgs, ... }:

{
  imports = [ noctalia.nixosModules.default ];

  environment.systemPackages = with pkgs; [
    brightnessctl
    ddcutil
  ];

  hardware.i2c.enable = true;

  programs.noctalia = {
    enable = true;
    # home manager provides the package
    package = null;
    recommendedServices.enable = true;
  };
}
