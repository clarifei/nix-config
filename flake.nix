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
      checks.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          noctalia-audio-grouping = pkgs.runCommand "noctalia-audio-grouping-test" {
            nativeBuildInputs = [
              pkgs.gcc
              pkgs.patch
            ];
          } ''
            cp -r ${noctalia.outPath} source
            chmod -R u+w source
            patch --directory=source --strip=1 < ${./home/desktop/patches/noctalia-audio-stream-grouping.patch}
            c++ -std=c++23 -Wall -Wextra -Werror -Isource/src \
              source/tests/program_output_group_key_test.cpp -o program-output-group-key-test
            ./program-output-group-key-test
            touch "$out"
          '';

          vesktop-screen-share-transaction = pkgs.runCommand "vesktop-screen-share-transaction-test" {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.patch
            ];
          } ''
            cp -r ${pkgs.vesktop.src} source
            chmod -R u+w source
            patch --directory=source --strip=1 < ${./modules/patches/vesktop-screen-share-transaction.patch}
            node --disable-warning=MODULE_TYPELESS_PACKAGE_JSON --test source/tests/singleFlight.test.ts
            touch "$out"
          '';

          xdpw-foot-chooser = pkgs.callPackage ./tests/xdpw-foot-chooser.nix { };
        };

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit nix-cachyos-kernel noctalia;
        };
        modules = [
          home-manager.nixosModules.home-manager
          ./configuration.nix
        ];
      };
    };
}
