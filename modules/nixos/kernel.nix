{ pkgs, ... }:

{
  # tune only the kernel for zen 4 to keep userspace cache-compatible
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-zen4;
}
