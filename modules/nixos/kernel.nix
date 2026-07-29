{
  host,
  lib,
  pkgs,
  ...
}:

let
  kernelProfiles = {
    generic = "linuxPackages-cachyos-bore-lto";
    zen4 = "linuxPackages-cachyos-bore-lto-zen4";
  };
  profile = host.cpu or "generic";
  kernelAttribute = kernelProfiles.${profile} or kernelProfiles.generic;
in

{
  boot.kernelPackages = lib.mkDefault (
    lib.attrByPath [
      "cachyosKernels"
      kernelAttribute
    ] pkgs.linuxPackages pkgs
  );
}
