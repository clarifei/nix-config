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

    dbx = {
      url = "github:t8y2/dbx";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-cachyos-kernel,
      noctalia,
      dbx,
      ...
    }:
    let
      hostDirectories = nixpkgs.lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists (./hosts + "/${name}/host.nix")
      ) (builtins.readDir ./hosts);
      hosts = builtins.mapAttrs (
        name: _: (import (./hosts + "/${name}/host.nix")) // { inherit name; }
      ) hostDirectories;
      hostSystems = nixpkgs.lib.unique (map (host: host.system) (builtins.attrValues hosts));
      mkHost =
        name: host:
        nixpkgs.lib.nixosSystem {
          inherit (host) system;
          specialArgs = {
            inherit
              dbx
              host
              nix-cachyos-kernel
              noctalia
              ;
          };
          modules = [
            home-manager.nixosModules.home-manager
            (./hosts + "/${name}")
          ];
        };
    in
    {
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost hosts;

      checks = builtins.listToAttrs (
        map (system: {
          name = system;
          value = import ./checks {
            inherit nixpkgs noctalia system;
          };
        }) hostSystems
      );

      formatter = builtins.listToAttrs (
        map (system: {
          name = system;
          value = nixpkgs.legacyPackages.${system}.nixfmt-tree;
        }) hostSystems
      );
    };
}
