{
  config,
  lib,
  pkgs,
  ...
}:

let
  codex = pkgs.callPackage ../../../packages/codex { };
in
{
  home.packages = [
    codex
  ]
  ++ (with pkgs; [
    fd
    fastfetch
    jq
    nodejs_latest
    pnpm
    python3
    ripgrep
    uv
    vesktop
    wayland-utils
    wlrctl
  ]);

  home.sessionVariables = {
    UV_NO_MANAGED_PYTHON = "1";
    UV_PYTHON_DOWNLOADS = "never";
  };

  # allow generated configs to replace stale home manager backups
  xdg.configFile = {
    "fastfetch/config.jsonc".source = ./fastfetch.jsonc;
    "foot/foot.ini".force = true;
  };
  # Keep the configured Vesktop ahead of a stale standalone ~/.nix-profile entry.
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
  home.file.".local/bin/vesktop".source = "${pkgs.vesktop}/bin/vesktop";
  home.file."${config.xdg.configHome}/starship.toml".force = true;

  programs = {
    home-manager.enable = true;
    git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        user = {
          email = "nightcoremosta@gmail.com";
          name = "Rendy Sebpian";
        };
      };
    };
    gh.enable = true;
    firefox = {
      enable = true;
      profiles.default = {
        # This is the existing default Firefox profile, not a new profile.
        path = "29azi75l.default";
        settings."toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        userChrome = ./firefox-userChrome.css;
        userContent = ./firefox-userContent.css;
      };
    };
    fish = {
      enable = true;
      functions.fish_greeting = "";
      interactiveShellInit = ''
        set -l noctalia_terminal_sequences "$HOME/.cache/noctalia/terminal-sequences"
        if test -r "$noctalia_terminal_sequences"
          command cat "$noctalia_terminal_sequences"
        end

        if test "$TERM" != dumb
          fastfetch
        end
      '';
    };
    starship = {
      enable = true;
      settings = builtins.fromTOML (builtins.readFile ./starship-prompt-mono.toml);
    };
    foot = {
      enable = true;
      settings = {
        main = {
          font = "GeistMono Nerd Font:size=11";
          dpi-aware = "yes";
          include = "~/.config/foot/themes/noctalia";
          pad = "8x8";
          shell = lib.getExe pkgs.fish;
        };
        scrollback.lines = 10000;
        mouse.hide-when-typing = "yes";
      };
    };
  };
}
