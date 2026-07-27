{
  noctalia,
  pkgs,
}:

(pkgs.callPackage "${noctalia}/nix/package.nix" { }).overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    ./patches/noctalia-smart-autohide-labwc.patch
    ./patches/noctalia-audio-stream-grouping.patch
    ./patches/noctalia-solid-bar.patch
  ];
})
