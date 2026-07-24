{
  hardware = {
    graphics.enable = true;
    nvidia = {
      # the rtx 4060 supports the open nvidia module
      open = true;
      nvidiaSettings = false;
    };
  };

  services = {
    xserver.videoDrivers = [ "nvidia" ];

    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
  };

  security.rtkit.enable = true;
}
