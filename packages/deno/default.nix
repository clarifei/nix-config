{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  unzip,
}:

let
  version = "2.9.5";
in
stdenv.mkDerivation {
  pname = "deno";
  inherit version;

  src = fetchurl {
    url = "https://github.com/denoland/deno/releases/download/v${version}/deno-x86_64-unknown-linux-gnu.zip";
    hash = "sha256-iwEKOxpKAYimfNuKeic0iypQGveK7H/HTyrOFnNo1TA=";
  };

  dontBuild = true;
  dontConfigure = true;
  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
  ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    install -d $out/bin
    unzip -p $src deno > $out/bin/deno
    chmod 755 $out/bin/deno
  '';

  meta = {
    description = "Secure runtime for JavaScript and TypeScript";
    homepage = "https://deno.com";
    license = lib.licenses.mit;
    mainProgram = "deno";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
