{
  appimageTools,
  fetchurl,
  lib,
}:

let
  pname = "dbx";
  version = "0.5.77";

  src = fetchurl {
    url = "https://github.com/t8y2/dbx/releases/download/v${version}/DBX_${version}_amd64.AppImage";
    hash = "sha256-BN1UQwzG6kRk1nLLv4uH3MPfMFq1rlUSzPVx0E4so6A=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/usr/share/applications/DBX.desktop \
      $out/share/applications/DBX.desktop
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/128x128/apps/dbx.png \
      $out/share/icons/hicolor/128x128/apps/dbx.png
  '';

  meta = {
    description = "Lightweight database management client for 70+ databases";
    homepage = "https://github.com/t8y2/dbx";
    changelog = "https://github.com/t8y2/dbx/releases/tag/v${version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "dbx";
  };
}
