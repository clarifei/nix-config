{
  imports = [
    ./home/desktop.nix
    ./home/programs.nix
  ];

  home = {
    username = "clarifei";
    homeDirectory = "/home/clarifei";
    stateVersion = "26.05";
  };
}
