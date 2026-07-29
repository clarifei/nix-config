{ host, noctalia, ... }:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit host noctalia;
    };
    users.${host.username} = import ../home;
  };
}
