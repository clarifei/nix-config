{ pkgs, ... }:

{
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
  };

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

  users.users.clarifei = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "i2c"
      "networkmanager"
      "wheel"
    ];
  };

  programs.fish.enable = true;
}
