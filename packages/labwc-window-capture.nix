{
  fetchFromGitHub,
  fetchFromGitLab,
  labwc,
  lcms2,
  lib,
  libGL,
  scenefx,
  wlroots_0_20,
}:

let
  wlroots = wlroots_0_20.overrideAttrs {
    version = "0.20.2";
    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "wlroots";
      repo = "wlroots";
      rev = "0.20.2";
      hash = "sha256-VdYymvzYp6/R255AK20j4xTd+JbCZgNiRfgeRJD+UZY=";
    };
  };

  # SceneFX needs to use the exact wlroots ABI used by Labwc. This commit is
  # the first 0.5.x revision synchronized with wlroots 0.20.2.
  scenefx_0_5 =
    (scenefx.override { wlroots_0_19 = wlroots; }).overrideAttrs
      (old: {
        version = "0.5.0-unstable-2026-07-13";
        src = fetchFromGitHub {
          owner = "wlrfx";
          repo = "scenefx";
          rev = "45c69780fc4fe5b9db0c3a1bac2521360b4538fb";
          hash = "sha256-XcYjecZ0xIoJqib0YAn2PZNXyHLOiG4G6J3xKqknNzs=";
        };
        patches = (old.patches or [ ]) ++ [ ./patches/scenefx-high-precision-blur.patch ];
        buildInputs = (old.buildInputs or [ ]) ++ [ lcms2 ];
        mesonFlags = (old.mesonFlags or [ ]) ++ [ "-Dexamples=false" ];
      });
in
(labwc.override { wlroots_0_19 = wlroots; }).overrideAttrs (old: {
  version = "0.20.1";
  src = fetchFromGitHub {
    owner = "labwc";
    repo = "labwc";
    tag = "0.20.1";
    hash = "sha256-1LINOZsdN5btT0VQvUwYXbSjuKdQdbkaI062OYAJSiE=";
  };

  patches = (old.patches or [ ]) ++ [
    ./patches/labwc-scenefx-renderer.patch
    ./patches/labwc-scenefx-window-effects.patch
    ./patches/labwc-scenefx-window-effects-docs.patch
  ];

  # The public SceneFX renderer header directly includes GLES2 headers.
  buildInputs = (old.buildInputs or [ ]) ++ [
    libGL
    scenefx_0_5
  ];

  # Home Manager already owns labwc-session.target for this configuration.
  mesonFlags = (old.mesonFlags or [ ]) ++ [ (lib.mesonEnable "systemd-session" false) ];
})
