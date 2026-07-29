{
  system = "x86_64-linux";
  username = "clarifei";
  stateVersion = "26.05";
  # pure eval cannot detect cpu; generate this value at install time if needed.
  cpu = "zen4";

  git = {
    name = "Rendy Sebpian";
    email = "nightcoremosta@gmail.com";
  };

  graphics = "nvidia";
  ddcutil = true;
}
