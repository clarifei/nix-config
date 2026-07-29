{
  config,
  host,
  lib,
  pkgs,
  ...
}:

let
  codex = pkgs.callPackage ../../../packages/codex { };
  graphifySupport = ../../../packages/graphify-nix-support;
in
{
  home.packages =
    lib.optional (pkgs.stdenv.hostPlatform.system == "x86_64-linux") codex
    ++ (with pkgs; [
      fd
      fastfetch
      jq
      nil
      nodejs_latest
      pnpm
      python3
      ripgrep
      uv
      vscode
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
    "Code/argv.json".text = builtins.toJSON {
      "password-store" = "gnome-libsecret";
    };
    "fastfetch/config.jsonc".source = ./fastfetch.jsonc;
    "foot/foot.ini".force = true;
  };
  # keep configured vesktop ahead of stale standalone profiles.
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
  home.file.".local/bin/vesktop".source = "${pkgs.vesktop}/bin/vesktop";
  home.file."${config.xdg.configHome}/starship.toml".force = true;
  home.file."${config.xdg.dataHome}/uv/tools/graphifyy/${pkgs.python3.sitePackages}/graphify-nix-support.pth".text =
    ''
      ${graphifySupport}
      import graphify_nix_support; graphify_nix_support.install()
    '';

  programs = {
    home-manager.enable = true;
    git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
      }
      // lib.optionalAttrs (host ? git) { user = host.git; };
    };
    gh.enable = true;
    firefox = {
      enable = true;
      profiles.default = {
        settings = {
          "browser.tabs.inTitlebar" = 0;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        };
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
