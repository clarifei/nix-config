{ host, ... }:

{
  imports = [
    ./desktop
    ./file-management
    ./programs
  ];

  home = {
    username = host.username;
    homeDirectory = host.homeDirectory or "/home/${host.username}";
    stateVersion = host.stateVersion;
  };
}
