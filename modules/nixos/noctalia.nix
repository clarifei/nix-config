{
  host,
  lib,
  noctalia,
  pkgs,
  ...
}:

let
  enableDdcutil = host.ddcutil or false;
in

{
  imports = [ noctalia.nixosModules.default ];

  environment.systemPackages =
    with pkgs;
    [
      brightnessctl
    ]
    ++ lib.optional enableDdcutil ddcutil;

  hardware.i2c.enable = lib.mkIf enableDdcutil true;

  programs.noctalia = {
    enable = true;
    # home manager provides the package
    package = null;
    recommendedServices.enable = true;
  };
}
