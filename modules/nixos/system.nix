{
  host,
  lib,
  pkgs,
  ...
}:

{
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    networkmanager.enable = true;
  };

  virtualisation.docker.enable = true;

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    ensureDatabases = [ host.username ];
    ensureUsers = [
      {
        name = host.username;
        ensureDBOwnership = true;
      }
    ];
  };

  environment.systemPackages = [ pkgs.docker-compose ];

  time.timeZone = "Asia/Jakarta";
  i18n.defaultLocale = "en_US.UTF-8";

  fonts = {
    packages = with pkgs; [
      geist-font
      nerd-fonts.geist-mono
    ];
    fontconfig.defaultFonts = {
      monospace = [ "GeistMono Nerd Font" ];
      sansSerif = [ "Geist" ];
    };
  };

  users.users.${host.username} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "docker"
      "networkmanager"
      "wheel"
    ]
    ++ lib.optional (host.ddcutil or false) "i2c";
  };

  programs.fish.enable = true;
}
