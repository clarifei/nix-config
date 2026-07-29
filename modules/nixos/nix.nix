{
  host,
  lib,
  pkgs,
  ...
}:

let
  allowUnfree = [
    "codex"
    "vscode"
  ]
  ++ lib.optional ((host.graphics or null) == "nvidia") "nvidia-x11";
in

{
  # keep bwrap in the system path for sandboxed tools
  environment.systemPackages = [ pkgs.bubblewrap ];

  nix = {
    settings = {
      auto-optimise-store = false;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # limit build concurrency for 32 gib of ram
      cores = 8;
      max-jobs = 2;
      extra-substituters = [
        "https://attic.xuyh0120.win/lantian"
        "https://noctalia.cachix.org"
      ];
      extra-trusted-public-keys = [
        "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) allowUnfree;

  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 7d --keep 5";
    };
  };
}
