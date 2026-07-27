{ noctalia, ... }:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit noctalia; };
    backupFileExtension = "hm-backup";
    users.clarifei = import ../home;
  };
}
