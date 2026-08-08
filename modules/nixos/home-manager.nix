{
  dbx,
  host,
  noctalia,
  ...
}:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit dbx host noctalia;
    };
    users.${host.username} = import ../home;
  };
}
