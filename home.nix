{
  imports = [
    ./home/desktop.nix
    ./home/file-management.nix
    ./home/programs.nix
  ];

  home = {
    username = "clarifei";
    homeDirectory = "/home/clarifei";
    stateVersion = "26.05";
  };
}
