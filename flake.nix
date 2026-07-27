{
  description = "Minimal Wayland-native NixOS configuration";

  nixConfig = {
    extra-substituters = [
      "https://attic.xuyh0120.win/lantian"
      "https://noctalia.cachix.org"
    ];
    extra-trusted-public-keys = [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    noctalia.url = "github:noctalia-dev/noctalia";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-cachyos-kernel,
      noctalia,
      ...
    }:
    {
      checks.x86_64-linux = import ./checks {
        inherit nixpkgs noctalia;
      };

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit nix-cachyos-kernel noctalia;
        };
        modules = [
          home-manager.nixosModules.home-manager
          ./hosts/nixos
        ];
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
    };
}
