{
  config,
  lib,
  pkgs,
  ...
}:

let
  action = name: attrs: { "@name" = name; } // attrs;
  execute = command: action "Execute" { "@command" = command; };
  windowSwitcher = pkgs.labwc-window-switcher;
  controlWindowSwitcher = mode: execute "${lib.getExe windowSwitcher} ${mode}";
  openWindowSwitcher = mode: [
    (action "ExportWindowList" { })
    (controlWindowSwitcher mode)
    (action "ExecuteOnModifierRelease" {
      "@command" = "${lib.getExe windowSwitcher} accept";
    })
  ];
  goToDesktop = desktop: action "GoToDesktop" { "@to" = toString desktop; };
  sendToDesktop =
    desktop:
    action "SendToDesktop" {
      "@to" = toString desktop;
      "@follow" = "yes";
    };

  desktopBindings =
    modifier: binding:
    builtins.genList (
      index:
      let
        desktop = index + 1;
      in
      {
        "@key" = "W-${modifier}${toString desktop}";
        action = binding desktop;
      }
    ) 9;
in
{
  wayland.windowManager.labwc.rc.keyboard = {
    default = true;
    keybind = [
      # applications
      {
        "@key" = "W-Return";
        action = execute "foot";
      }
      {
        "@key" = "W-Space";
        action = execute "noctalia msg panel-toggle launcher";
      }
      {
        "@key" = "W-b";
        action = execute "firefox";
      }
      {
        "@key" = "W-e";
        action = execute "foot --app-id=yazi ${lib.getExe config.programs.yazi.package}";
      }

      # window management
      {
        "@key" = "W-q";
        action = action "Close" { };
      }
      {
        "@key" = "W-f";
        action = action "ToggleFullscreen" { };
      }
      {
        "@key" = "W-m";
        action = action "ToggleMaximize" { };
      }
      {
        "@key" = "A-Tab";
        action = openWindowSwitcher "next";
      }
      {
        "@key" = "A-S-Tab";
        action = openWindowSwitcher "previous";
      }
      {
        "@key" = "W-Tab";
        action = openWindowSwitcher "next";
      }
      {
        "@key" = "W-S-Tab";
        action = openWindowSwitcher "previous";
      }
      {
        "@key" = "W-d";
        action = action "If" {
          query.decoration = "full";
          "then".action = action "SetDecorations" {
            "@decorations" = "border";
            "@forceSSD" = "yes";
          };
          "else".action = action "SetDecorations" {
            "@decorations" = "full";
            "@forceSSD" = "yes";
          };
        };
      }
      {
        "@key" = "W-S-d";
        action = action "ToggleWindowEffects" { };
      }
      {
        "@key" = "W-h";
        action = action "SnapToEdge" { "@direction" = "left"; };
      }
      {
        "@key" = "W-j";
        action = action "SnapToEdge" { "@direction" = "down"; };
      }
      {
        "@key" = "W-k";
        action = action "SnapToEdge" { "@direction" = "up"; };
      }
      {
        "@key" = "W-l";
        action = action "SnapToEdge" { "@direction" = "right"; };
      }

      # noctalia panels and actions
      {
        "@key" = "Super_L";
        "@onRelease" = "yes";
        action = execute "noctalia msg panel-toggle control-center";
      }
      {
        "@key" = "W-s";
        action = execute "noctalia msg settings-toggle";
      }
      {
        "@key" = "W-v";
        action = execute "noctalia msg panel-toggle clipboard";
      }
      {
        "@key" = "W-S-s";
        action = execute "noctalia msg screenshot-region";
      }

      # media and brightness
      {
        "@key" = "XF86AudioRaiseVolume";
        action = execute "noctalia msg volume-up";
      }
      {
        "@key" = "XF86AudioLowerVolume";
        action = execute "noctalia msg volume-down";
      }
      {
        "@key" = "XF86AudioMute";
        action = execute "noctalia msg volume-mute";
      }
      {
        "@key" = "XF86MonBrightnessUp";
        action = execute "noctalia msg brightness-up";
      }
      {
        "@key" = "XF86MonBrightnessDown";
        action = execute "noctalia msg brightness-down";
      }

      # session
      {
        "@key" = "C-A-Delete";
        action = execute "noctalia msg panel-toggle session";
      }
      {
        "@key" = "W-S-E";
        action = action "Exit" { };
      }
    ]
    ++ desktopBindings "" goToDesktop
    ++ desktopBindings "S-" sendToDesktop;
  };
}
