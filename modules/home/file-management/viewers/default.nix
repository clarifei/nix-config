{
  lib,
  pkgs,
  ...
}:

let
  documentTypes = import ../document-types.nix;
  swayimgPackage = pkgs.swayimg.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ./patches/swayimg-window-behavior.patch ];
  });
in
{
  xdg.mimeApps = {
    enable = true;

    # use swayimg's packaged mime list
    defaultApplicationPackages = [ swayimgPackage ];
    defaultApplications = lib.mergeAttrsList (
      map (handler: lib.genAttrs handler.mimeTypes (_: [ handler.desktop ])) documentTypes.handlers
    );
  };

  programs = {
    swayimg = {
      enable = true;
      package = swayimgPackage;
      settings = {
        general = {
          decoration = "yes";
          size = "image";
        };
        viewer = {
          scale = "fit";
          window = "auto";
        };
        list = {
          all = "yes";
          order = "numeric";
        };
        "keys.viewer" = {
          Left = "prev_file";
          Right = "next_file";
          F11 = "fullscreen";
          "Ctrl+w" = "exit";
          "Ctrl+r" = "rotate_right";
          "Ctrl+0" = "zoom fit";
          "Ctrl+1" = "zoom real";
          "Ctrl+Equal" = "zoom +10";
          "Ctrl+Shift+Plus" = "zoom +10";
          "Ctrl+Minus" = "zoom -10";
          "Shift+Delete" = "none";
          ScrollUp = "zoom +10 mouse";
          ScrollDown = "zoom -10 mouse";
        };
        "keys.slideshow" = {
          Left = "prev_file";
          Right = "next_file";
          F11 = "fullscreen";
          "Ctrl+w" = "exit";
        };
        "keys.gallery" = {
          F11 = "fullscreen";
          "Ctrl+w" = "exit";
          "Ctrl+Equal" = "thumb +20";
          "Ctrl+Shift+Plus" = "thumb +20";
          "Ctrl+Minus" = "thumb -20";
          "Shift+Delete" = "none";
        };
      };
    };

    zathura = {
      enable = true;
      options.selection-clipboard = "clipboard";
      mappings = {
        "<C-o>" = "file_chooser";
        "<C-w>" = "quit";
        "[fullscreen] <C-w>" = "quit";
        "<A-Left>" = "jumplist backward";
        "<A-Right>" = "jumplist forward";
        "<C-Home>" = "goto top";
        "<C-End>" = "goto bottom";
        "<C-f>" = "focus_inputbar /";
        "<F3>" = "search forward";
        "<S-F3>" = "search backward";
        "<C-=>" = "zoom in";
        "<C-+>" = "zoom in";
        "<C-->" = "zoom out";
        "<C-KPAdd>" = "zoom in";
        "<C-KPSubtract>" = "zoom out";
        "<C-0>" = "adjust_window best-fit";
        "<C-1>" = "zoom specific";
        "<C-2>" = "adjust_window width";
        "<C-r>" = "reload";
      };
      extraConfig = "include noctaliarc";
    };
  };
}
