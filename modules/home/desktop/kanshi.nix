{
  systemd.user.services.kanshi.Service.RestartSec = 3;

  services.kanshi = {
    enable = true;
    settings = [
      {
        profile = {
          name = "desktop";
          outputs = [
            {
              criteria = "Acer Technologies XV252Q F 140509CDE4201";
              status = "enable";
              mode = "1920x1080@390.297Hz";
              position = "0,0";
              scale = 1.0;
              transform = "normal";
              adaptiveSync = false;
            }
          ];
        };
      }
    ];
  };
}
