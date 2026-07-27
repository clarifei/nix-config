{
  nixpkgs,
  noctalia,
}:

let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
in
{
  labwc-scenefx = pkgs.callPackage ../packages/labwc { };

  noctalia = import ../packages/noctalia { inherit noctalia pkgs; };

  noctalia-audio-grouping =
    pkgs.runCommand "noctalia-audio-grouping-test"
      {
        nativeBuildInputs = [
          pkgs.gcc
          pkgs.patch
        ];
      }
      ''
        cp -r ${noctalia.outPath} source
        chmod -R u+w source
        patch --directory=source --strip=1 < ${../packages/noctalia/patches/noctalia-audio-stream-grouping.patch}
        c++ -std=c++23 -Wall -Wextra -Werror -Isource/src \
          source/tests/program_output_group_key_test.cpp -o program-output-group-key-test
        ./program-output-group-key-test
        touch "$out"
      '';

  vesktop-screen-share-transaction =
    pkgs.runCommand "vesktop-screen-share-transaction-test"
      {
        nativeBuildInputs = [
          pkgs.gnugrep
          pkgs.nodejs
          pkgs.patch
        ];
      }
      ''
        cp -r ${pkgs.vesktop.src} source
        chmod -R u+w source
        patch --directory=source --strip=1 < ${../packages/vesktop/patches/vesktop-screen-share-transaction.patch}
        grep -Fq 'width: 960' source/src/main/screenShare.ts
        grep -Fq 'height: 540' source/src/main/screenShare.ts
        node --disable-warning=MODULE_TYPELESS_PACKAGE_JSON --test source/tests/singleFlight.test.ts
        touch "$out"
      '';

  vesktop-square-splash =
    pkgs.runCommand "vesktop-square-splash-test"
      {
        nativeBuildInputs = [
          pkgs.gnugrep
          pkgs.patch
        ];
      }
      ''
        cp -r ${pkgs.vesktop.src} source
        chmod -R u+w source
        patch --directory=source --strip=1 < ${../packages/vesktop/patches/vesktop-square-splash.patch}
        grep -Fq 'border-radius: 0;' source/static/views/splash.html
        grep -Fq 'border: 0;' source/static/views/splash.html
        grep -Fq 'background: var(--bg);' source/static/views/splash.html
        grep -Fq 'hasShadow: false' source/src/main/splash.ts
        touch "$out"
      '';

  vesktop-wayland-picker-runtime =
    let
      vesktop = pkgs.callPackage ../packages/vesktop { };
    in
    pkgs.runCommand "vesktop-wayland-picker-runtime-test" { } ''
      grep -Fq '${pkgs.electron_41}/bin/electron' ${vesktop}/bin/vesktop
      touch "$out"
    '';

  termfilechooser-filters = pkgs.callPackage ../packages/xdg-desktop-portal-termfilechooser { };

  xdpw-window-restore = pkgs.callPackage ../packages/xdg-desktop-portal-wlr { };

  xdpw-foot-chooser = pkgs.callPackage ./xdpw-foot-chooser.nix { };
  labwc-window-switcher = pkgs.callPackage ./labwc-window-switcher.nix { };
}
