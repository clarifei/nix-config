{
  electron_41,
  vesktop,
}:

# electron 42 times out before portal selection completes; electron 41 waits for the event.
(vesktop.override { electron_42 = electron_41; }).overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    ./patches/vesktop-screen-share-transaction.patch
    ./patches/vesktop-square-splash.patch
  ];
})
