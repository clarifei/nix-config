{
  fetchurl,
  lib,
  stdenvNoCC,
}:

let
  binary = "codex-x86_64-unknown-linux-musl";
  version = "0.147.0";
in
stdenvNoCC.mkDerivation {
  pname = "codex";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/${binary}.tar.gz";
    hash = "sha256-Akbi53ODTgfw+1JJ7W660S5FkeYI+Me7l91qlpBUTDY=";
  };

  dontBuild = true;
  dontConfigure = true;
  dontUnpack = true;

  installPhase = ''
    install -d $out/bin

    tar -xzf "$src" -O "${binary}" > "$out/bin/codex"
    chmod 755 "$out/bin/codex"

    host_binary="$(tar -tzf "$src" | grep -E '^codex-code-mode-host(-|$)' | head
    -n1)"
    test -n "$host_binary"

    tar -xzf "$src" -O "$host_binary" > "$out/bin/codex-code-mode-host"
    chmod 755 "$out/bin/codex-code-mode-host"
  '';

  meta = {
    description = "OpenAI Codex command-line interface";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "codex";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
