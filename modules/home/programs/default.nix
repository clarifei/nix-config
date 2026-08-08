{
  config,
  host,
  lib,
  pkgs,
  ...
}:

let
  codex = pkgs.callPackage ../../../packages/codex { };
  codebaseMemoryMcp = pkgs.callPackage ../../../packages/codebase-memory-mcp { };
  dbx = pkgs.callPackage ../../../packages/dbx { };
  rtk = pkgs.callPackage ../../../packages/rtk { };
in
{
  home.packages =
    lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
      codex
      codebaseMemoryMcp
      dbx
      rtk
    ]
    ++ (with pkgs; [
      cargo
      deno
      fd
      fastfetch
      jq
      nodejs_24
      pnpm
      python3
      ripgrep
      rustc
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
      "password-store" = "basic";
    };
    "fastfetch/config.jsonc".source = ./fastfetch.jsonc;
    "foot/foot.ini".force = true;
  };
  # keep configured vesktop ahead of stale standalone profiles.
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
  home.file.".local/bin/vesktop".source = "${pkgs.vesktop}/bin/vesktop";
  home.file.".local/bin/rtk" = {
    source = "${rtk}/bin/rtk";
    force = true;
  };
  home.file."${config.xdg.configHome}/starship.toml".force = true;
  home.activation.codebaseMemoryMcp = lib.hm.dag.entryAfter [ "installPackages" ] ''
    run ${lib.getExe codex} mcp add codebase-memory-mcp -- ${lib.getExe codebaseMemoryMcp}
    run ${pkgs.coreutils}/bin/rm -f "${config.home.homeDirectory}/.local/share/codebase-memory-mcp/codebase-memory-mcp"
  '';
  home.activation.legacyUserInstallCleanup = lib.hm.dag.entryAfter [ "codebaseMemoryMcp" ] ''
    run ${pkgs.coreutils}/bin/rm -rf "${config.home.homeDirectory}/.local/share/GitKrakenCLI/versions"
    run ${pkgs.coreutils}/bin/rm -f "${config.home.homeDirectory}/.local/share/GitKrakenCLI/gk"
    run ${pkgs.coreutils}/bin/rm -rf "${config.xdg.dataHome}/uv/python"
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
