{ ... }:

{
  hardware.nvidia = {
    open = true;
    nvidiaSettings = false;
  };

  services.xserver.videoDrivers = [ "nvidia" ];
}
