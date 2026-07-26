{
  fetchFromGitHub,
  fetchFromGitLab,
  labwc,
  lib,
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
in
(labwc.override { wlroots_0_19 = wlroots; }).overrideAttrs (old: {
  version = "0.20.1";
  src = fetchFromGitHub {
    owner = "labwc";
    repo = "labwc";
    tag = "0.20.1";
    hash = "sha256-1LINOZsdN5btT0VQvUwYXbSjuKdQdbkaI062OYAJSiE=";
  };

  # Home Manager already owns labwc-session.target for this configuration.
  mesonFlags = (old.mesonFlags or [ ]) ++ [ (lib.mesonEnable "systemd-session" false) ];
})
