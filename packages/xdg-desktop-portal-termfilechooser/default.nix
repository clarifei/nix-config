{ xdg-desktop-portal-termfilechooser }:

xdg-desktop-portal-termfilechooser.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    ./patches/termfilechooser-filters.patch
  ];
})
