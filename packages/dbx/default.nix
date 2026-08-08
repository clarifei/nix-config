{ dbxFlake }:

dbxFlake.packages.x86_64-linux.dbx-desktop.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./remove-custom-window-chrome.patch ];
})
