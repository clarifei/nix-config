{ xdg-desktop-portal-wlr }:

xdg-desktop-portal-wlr.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    ../modules/patches/xdpw-window-restore.patch
  ];
})
