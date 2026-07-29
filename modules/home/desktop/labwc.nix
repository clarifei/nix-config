let
  effectsOpacity = 0.90;
  grainAmount = 0.08;
  grainSize = 1.0;
in
{
  imports = [ ./labwc-keybinds.nix ];

  # allow the generated config to replace stale home manager backups
  xdg.configFile."labwc/rc.xml".force = true;

  wayland.windowManager.labwc = {
    enable = true;
    package = null;

    rc = {
      core.gap = 10;
      desktops = {
        "@number" = 9;
        popupTime = 0;
        prefix = "Workspace";
      };
      theme = {
        name = "noctalia";
        cornerRadius = 0;
        titlebar = {
          # an empty layout removes buttons without hiding the titlebar
          layout = ":";
          showTitle = "yes";
        };
      };
      windowEffects = {
        enabled = "yes";
        activeOpacity = effectsOpacity;
        inactiveOpacity = 0.80;
        layerShell = {
          enabled = "yes";
          opacity = effectsOpacity;
        };
        blur = {
          enabled = "yes";
          # blur damage grows with passes; keep expansion low.
          passes = 2;
          radius = 4;
          brightness = 0.9;
          contrast = 0.9;
          saturation = 1.1;
          grain = {
            enabled = "yes";
            amount = grainAmount;
            size = grainSize;
          };
        };
      };
      windowSwitcher = {
        "@preview" = "no";
        "@outlines" = "no";
        "@unshade" = "no";
        osd."@show" = "no";
      };
      windowRules.windowRule = [
        {
          "@identifier" = "*";
          "@serverDecoration" = "yes";
          action = {
            "@name" = "SetDecorations";
            "@decorations" = "border";
            "@forceSSD" = "yes";
          };
        }
        {
          "@identifier" = "labwc-window-switcher";
          "@serverDecoration" = "yes";
          "@skipTaskbar" = "yes";
          "@skipWindowSwitcher" = "yes";
          "@fixedPosition" = "yes";
          action = [
            {
              "@name" = "SetDecorations";
              "@decorations" = "none";
              "@forceSSD" = "yes";
            }
            { "@name" = "ToggleAlwaysOnTop"; }
            {
              "@name" = "AutoPlace";
              "@policy" = "center";
            }
          ];
        }
      ];

      # omit default bindings to keep wallpaper clicks unbound
      mouse.context = [
        {
          "@name" = "Frame";
          mousebind = [
            {
              "@button" = "W-Left";
              "@action" = "Press";
              action = [
                { "@name" = "Focus"; }
                { "@name" = "Raise"; }
              ];
            }
            {
              "@button" = "W-Left";
              "@action" = "Drag";
              action = {
                "@name" = "Move";
              };
            }
            {
              "@button" = "W-Right";
              "@action" = "Press";
              action = [
                { "@name" = "Focus"; }
                { "@name" = "Raise"; }
              ];
            }
            {
              "@button" = "W-Right";
              "@action" = "Drag";
              action = {
                "@name" = "Resize";
              };
            }
          ];
        }
        {
          "@name" = "Border";
          mousebind = [
            {
              "@button" = "Left";
              "@action" = "Press";
              action = [
                { "@name" = "Focus"; }
                { "@name" = "Raise"; }
              ];
            }
            {
              "@button" = "Left";
              "@action" = "Drag";
              action = {
                "@name" = "Resize";
              };
            }
          ];
        }
        {
          "@name" = "TitleBar";
          mousebind = [
            {
              "@button" = "Left";
              "@action" = "Press";
              action = [
                { "@name" = "Focus"; }
                { "@name" = "Raise"; }
              ];
            }
          ];
        }
        {
          "@name" = "Title";
          mousebind = [
            {
              "@button" = "Left";
              "@action" = "Drag";
              action = {
                "@name" = "Move";
              };
            }
            {
              "@button" = "Left";
              "@action" = "DoubleClick";
              action = {
                "@name" = "ToggleMaximize";
              };
            }
            {
              "@button" = "Right";
              "@action" = "Click";
              action = {
                "@name" = "ShowMenu";
                "@menu" = "client-menu";
              };
            }
          ];
        }
        {
          "@name" = "Client";
          mousebind = [
            {
              "@button" = "Left";
              "@action" = "Press";
              action = [
                { "@name" = "Focus"; }
                { "@name" = "Raise"; }
              ];
            }
            {
              "@direction" = "W-Up";
              "@action" = "Scroll";
              action = {
                "@name" = "GoToDesktop";
                "@to" = "left";
                "@wrap" = "yes";
              };
            }
            {
              "@direction" = "W-Down";
              "@action" = "Scroll";
              action = {
                "@name" = "GoToDesktop";
                "@to" = "right";
                "@wrap" = "yes";
              };
            }
            {
              "@direction" = "W-S-Up";
              "@action" = "Scroll";
              action = {
                "@name" = "SendToDesktop";
                "@to" = "left";
                "@follow" = "yes";
                "@wrap" = "yes";
              };
            }
            {
              "@direction" = "W-S-Down";
              "@action" = "Scroll";
              action = {
                "@name" = "SendToDesktop";
                "@to" = "right";
                "@follow" = "yes";
                "@wrap" = "yes";
              };
            }
          ];
        }
        {
          "@name" = "Root";
          # use wallpaper scrolling only for workspace navigation
          mousebind = [
            {
              "@direction" = "Up";
              "@action" = "Scroll";
              action = {
                "@name" = "GoToDesktop";
                "@to" = "left";
                "@wrap" = "yes";
              };
            }
            {
              "@direction" = "W-Up";
              "@action" = "Scroll";
              action = {
                "@name" = "GoToDesktop";
                "@to" = "left";
                "@wrap" = "yes";
              };
            }
            {
              "@direction" = "W-S-Up";
              "@action" = "Scroll";
              action = {
                "@name" = "SendToDesktop";
                "@to" = "left";
                "@follow" = "yes";
                "@wrap" = "yes";
              };
            }
            {
              "@direction" = "Down";
              "@action" = "Scroll";
              action = {
                "@name" = "GoToDesktop";
                "@to" = "right";
                "@wrap" = "yes";
              };
            }
            {
              "@direction" = "W-Down";
              "@action" = "Scroll";
              action = {
                "@name" = "GoToDesktop";
                "@to" = "right";
                "@wrap" = "yes";
              };
            }
            {
              "@direction" = "W-S-Down";
              "@action" = "Scroll";
              action = {
                "@name" = "SendToDesktop";
                "@to" = "right";
                "@follow" = "yes";
                "@wrap" = "yes";
              };
            }
          ];
        }
      ];
    };

    environment = [
      "XDG_CURRENT_DESKTOP=labwc:wlroots"
      "XDG_SESSION_DESKTOP=labwc"
      "NIXOS_OZONE_WL=1"
      "MOZ_ENABLE_WAYLAND=1"
    ];

    autostart = [ "noctalia --daemon" ];

    menu = [
      {
        menuId = "client-menu";
        label = "Window";
        items = [
          {
            label = "Maximize";
            action.name = "ToggleMaximize";
          }
          {
            label = "Fullscreen";
            action.name = "ToggleFullscreen";
          }
          { separator = { }; }
          {
            label = "Close";
            action.name = "Close";
          }
        ];
      }
    ];
  };
}
