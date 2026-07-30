{
  fetchurl,
  lib,
  stdenvNoCC,
}:

let
  binary = "rtk";
  version = "0.44.1";
in
stdenvNoCC.mkDerivation {
  pname = binary;
  inherit version;

  src = fetchurl {
    url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-mG8pcERps9EFHiR0EFxsdauLc2UQaNzWFhLB+zk4rZU=";
  };

  dontBuild = true;
  dontConfigure = true;
  dontUnpack = true;

  installPhase = ''
    install -d $out/bin
    tar -xzf $src -O ${binary} > $out/bin/${binary}
    chmod 755 $out/bin/${binary}
  '';

  meta = {
    description = "Rust Token Killer command-line proxy";
    homepage = "https://github.com/rtk-ai/rtk";
    license = lib.licenses.asl20;
    mainProgram = binary;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
