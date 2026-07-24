{ nix-cachyos-kernel, pkgs, ... }:

{
  # tune only the kernel for zen 4 to keep userspace cache-compatible
  nixpkgs.overlays = [ nix-cachyos-kernel.overlays.pinned ];
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-zen4;
}
