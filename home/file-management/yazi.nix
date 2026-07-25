{
  config,
  lib,
  pkgs,
  ...
}:

let
  documentTypes = import ./document-types.nix;
  documentMimeTypes = lib.concatMap (handler: handler.mimeTypes) documentTypes.handlers;
  documentExtensions = lib.concatStringsSep "," documentTypes.extensions;
in
{
  programs.yazi = {
    enable = true;
    settings = {
      opener = {
        folder = [
          {
            run = "${pkgs.yazi}/bin/ya emit enter";
            desc = "enter folder";
          }
        ];
        image = [
          {
            run = "${lib.getExe config.programs.swayimg.package} -- %s";
            orphan = true;
            desc = "open image";
          }
        ];
        document = [
          {
            run = "${lib.getExe pkgs.zathura} -- %s";
            orphan = true;
            desc = "open document";
          }
        ];
      };
      open.prepend_rules = [
        {
          url = "*/";
          use = "folder";
        }
        {
          url = "*.{${documentExtensions}}";
          use = "document";
        }
      ]
      ++ map (mime: {
        inherit mime;
        use = "document";
      }) documentMimeTypes
      ++ [
        {
          mime = "image/*";
          use = "image";
        }
      ];
    };
    keymap.mgr.prepend_keymap = [
      {
        on = [ "<Backspace>" ];
        run = "leave";
        desc = "go up";
      }
      {
        on = [ "<A-Up>" ];
        run = "leave";
        desc = "go up";
      }
      {
        on = [ "<A-Left>" ];
        run = "back";
        desc = "go back";
      }
      {
        on = [ "<A-Right>" ];
        run = "forward";
        desc = "go forward";
      }
      {
        on = [ "<F2>" ];
        run = "rename --cursor=before_ext";
        desc = "rename";
      }
      {
        on = [ "<Delete>" ];
        run = "remove";
        desc = "move to trash";
      }
      {
        on = [ "<S-Delete>" ];
        run = "remove --permanently";
        desc = "delete permanently";
      }
      {
        on = [ "<C-c>" ];
        run = "yank";
        desc = "copy";
      }
      {
        on = [ "<C-x>" ];
        run = "yank --cut";
        desc = "cut";
      }
      {
        on = [ "<C-v>" ];
        run = "paste";
        desc = "paste";
      }
      {
        on = [ "<C-S-n>" ];
        run = "create --dir";
        desc = "new folder";
      }
      {
        on = [ "<C-l>" ];
        run = "cd --interactive";
        desc = "open location";
      }
      {
        on = [ "<F5>" ];
        run = "refresh";
        desc = "refresh";
      }
    ];
  };
}
