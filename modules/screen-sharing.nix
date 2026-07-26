{ lib, pkgs, ... }:

let
  chooser = pkgs.callPackage ../packages/xdpw-foot-chooser.nix { };
in
{
  xdg.portal.wlr.settings.screencast = {
    chooser_type = "dmenu";
    chooser_cmd = lib.getExe chooser;
    max_fps = 60;
  };
}
