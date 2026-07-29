{
  hardware.graphics.enable = true;

  services = {
    gnome.gnome-keyring.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
  };

  security.rtkit.enable = true;
}
