{ xdg-desktop-portal-wlr }:

xdg-desktop-portal-wlr.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    ./patches/xdpw-window-restore.patch
  ];
})
