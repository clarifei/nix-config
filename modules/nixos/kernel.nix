{ lib, pkgs, ... }:

{
  boot.kernelPackages = lib.mkDefault (
    lib.attrByPath [
      "cachyosKernels"
      "linuxPackages-cachyos-bore-lto"
    ] pkgs.linuxPackages pkgs
  );
}
