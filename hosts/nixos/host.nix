{
  system = "x86_64-linux";
  username = "clarifei";
  stateVersion = "26.05";
  # ponytail: pure eval cannot read CPU model; add an install-time generator if needed.
  cpu = "zen4";

  git = {
    name = "Rendy Sebpian";
    email = "nightcoremosta@gmail.com";
  };

  graphics = "nvidia";
  ddcutil = true;
}
