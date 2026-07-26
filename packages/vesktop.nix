{
  electron_41,
  vesktop,
}:

# Electron 42 times out delegated PipeWire source lists after three seconds, before
# the portal chooser has necessarily completed. Electron 41 waits for the delegated
# selection event; Electron 43 has the equivalent upstream fix but is not packaged yet.
(vesktop.override { electron_42 = electron_41; }).overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    ../modules/patches/vesktop-screen-share-transaction.patch
    ../modules/patches/vesktop-square-splash.patch
  ];
})
