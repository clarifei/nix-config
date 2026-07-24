{
  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
      priority = 10;
    }
  ];

  zramSwap = {
    enable = true;
    memoryPercent = 25;
    priority = 100;
  };
}
