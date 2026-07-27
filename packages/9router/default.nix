{
  buildNpmPackage,
  fetchurl,
  lib,
  makeWrapper,
  nodejs,
}:

buildNpmPackage {
  pname = "9router";
  version = "0.5.40";

  src = fetchurl {
    url = "https://registry.npmjs.org/9router/-/9router-0.5.40.tgz";
    hash = "sha256-Q3k15/dRTN1BWjEGE+qseBWyn/lFOzHRHo0xmlEm240=";
  };

  sourceRoot = "package";
  npmDepsHash = "sha256-4af0i6R2/myKvXh0+bZo8yE/tpEnXoPyTEIM8Moa8Z8=";
  dontNpmBuild = true;
  npmRebuildFlags = [ "--ignore-scripts" ];

  # The published tarball contains the built standalone web application. The
  # lockfile is generated locally because npm does not publish one in the tarball.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  installPhase = ''
    runHook preInstall
    install -d "$out/lib/9router" "$out/bin"
    cp -r . "$out/lib/9router"
    makeWrapper ${nodejs}/bin/node "$out/bin/9router" \
      --add-flags "$out/lib/9router/cli.js --skip-update"
    runHook postInstall
  '';

  meta = {
    description = "AI router and token saver CLI";
    homepage = "https://9router.com";
    license = lib.licenses.mit;
    mainProgram = "9router";
  };
}
