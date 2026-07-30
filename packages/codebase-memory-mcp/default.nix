{
  fetchurl,
  lib,
  stdenvNoCC,
}:

let
  binary = "codebase-memory-mcp";
  version = "0.9.0";
in
stdenvNoCC.mkDerivation {
  pname = binary;
  inherit version;

  src = fetchurl {
    url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/${binary}-linux-amd64-portable.tar.gz";
    hash = "sha256-hFnVydFFfyyC3j3jB//HZB7Lui3eiTQnvh5i7KjvmyU=";
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
    description = "Local codebase knowledge graph MCP server";
    homepage = "https://github.com/DeusData/codebase-memory-mcp";
    license = lib.licenses.mit;
    mainProgram = binary;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
