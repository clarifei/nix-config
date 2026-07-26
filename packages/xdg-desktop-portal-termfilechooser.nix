{ xdg-desktop-portal-termfilechooser }:

xdg-desktop-portal-termfilechooser.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    ../modules/patches/termfilechooser-filters.patch
  ];
})
