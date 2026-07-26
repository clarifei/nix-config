{
  noctalia,
  pkgs,
}:

(pkgs.callPackage "${noctalia}/nix/package.nix" { }).overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    ../home/desktop/patches/noctalia-smart-autohide-labwc.patch
    ../home/desktop/patches/noctalia-audio-stream-grouping.patch
    ../home/desktop/patches/noctalia-solid-bar.patch
  ];
})
