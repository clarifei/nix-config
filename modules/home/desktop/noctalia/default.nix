{
  config,
  noctalia,
  pkgs,
  ...
}:

let
  esc = builtins.fromJSON ''"\u001b"'';
  bel = builtins.fromJSON ''"\u0007"'';
  osc = code: value: "${esc}]${code};${value}${bel}";

  noctaliaPatched = import ../../../../packages/noctalia { inherit noctalia pkgs; };

  terminalSequences = builtins.concatStringsSep "" [
    (osc "10" "{{colors.terminal_foreground.default.hex}}")
    (osc "11" "{{colors.terminal_background.default.hex}}")
    (osc "12" "{{colors.terminal_cursor.default.hex}}")
    (osc "17" "{{colors.terminal_selection_bg.default.hex}}")
    (osc "19" "{{colors.terminal_selection_fg.default.hex}}")
    (osc "4;0" "{{colors.terminal_normal_black.default.hex}}")
    (osc "4;1" "{{colors.terminal_normal_red.default.hex}}")
    (osc "4;2" "{{colors.terminal_normal_green.default.hex}}")
    (osc "4;3" "{{colors.terminal_normal_yellow.default.hex}}")
    (osc "4;4" "{{colors.terminal_normal_blue.default.hex}}")
    (osc "4;5" "{{colors.terminal_normal_magenta.default.hex}}")
    (osc "4;6" "{{colors.terminal_normal_cyan.default.hex}}")
    (osc "4;7" "{{colors.terminal_normal_white.default.hex}}")
    (osc "4;8" "{{colors.terminal_bright_black.default.hex}}")
    (osc "4;9" "{{colors.terminal_bright_red.default.hex}}")
    (osc "4;10" "{{colors.terminal_bright_green.default.hex}}")
    (osc "4;11" "{{colors.terminal_bright_yellow.default.hex}}")
    (osc "4;12" "{{colors.terminal_bright_blue.default.hex}}")
    (osc "4;13" "{{colors.terminal_bright_magenta.default.hex}}")
    (osc "4;14" "{{colors.terminal_bright_cyan.default.hex}}")
    (osc "4;15" "{{colors.terminal_bright_white.default.hex}}")
  ];

  labwcTheme = ''
    # noctalia colors for labwc
    # use a two-pixel border for a stronger frame outline
    border.width: 2
    # button height sets the minimum titlebar height
    window.button.height: 22
    window.active.border.color: {{colors.surface_container_lowest.default.hex}}
    window.inactive.border.color: {{colors.surface_container_lowest.default.hex}}
    window.active.indicator.toggled-keybind.color: {{colors.error.default.hex}}
    window.active.title.bg.color: {{colors.primary.default.hex}}
    window.inactive.title.bg.color: {{colors.secondary.default.hex}}
    window.active.label.text.color: {{colors.on_primary.default.hex}}
    window.inactive.label.text.color: {{colors.on_secondary.default.hex}}
    window.label.text.justify: center
    menu.border.color: {{colors.on_primary.default.hex}}
    menu.items.bg.color: {{colors.primary.default.hex}}
    menu.items.text.color: {{colors.on_primary.default.hex}}
    menu.items.active.bg.color: {{colors.secondary.default.hex}}
    menu.items.active.text.color: {{colors.on_secondary.default.hex}}
    menu.separator.color: {{colors.on_primary.default.hex}}
    menu.title.bg.color: {{colors.primary.default.hex}}
    menu.title.text.color: {{colors.on_primary.default.hex}}
    osd.bg.color: {{colors.primary.default.hex}}
    osd.border.color: {{colors.on_primary.default.hex}}
    osd.label.text.color: {{colors.on_primary.default.hex}}
  '';

  templateRoot = "${config.xdg.configHome}/noctalia/templates";
  wallpaperDirectory = "${config.home.homeDirectory}/Downloads";
  wallpaper = "${wallpaperDirectory}/839532.jpg";
in
{
  imports = [ noctalia.homeModules.default ];

  xdg.configFile = {
    "noctalia/templates/terminal-sequences".text = terminalSequences;
    "noctalia/templates/labwc".text = labwcTheme;
  };

  programs.noctalia = {
    enable = true;
    package = noctaliaPatched;
    settings = {
      bar.default = {
        smart_auto_hide = true;
        background_opacity = 0.0;
        border_width = 0.0;
        capsule = true;
        capsule_fill = "on_primary";
        capsule_foreground = "on_primary";
        capsule_radius = 0;
        center = [ ];
        end = [ ];
        margin_edge = 6;
        margin_ends = 0;
        layer = "overlay";
        padding = 10;
        position = "bottom";
        radius = 0;
        reserve_space = false;
        start = [ "workspaces" ];
      };

      lockscreen_widgets = {
        enabled = false;
        schema_version = 2;
        widget_order = [ "lockscreen-login-box@DP-1" ];
        grid = {
          cell_size = 16;
          major_interval = 4;
          visible = true;
        };
        widget."lockscreen-login-box@DP-1" = {
          box_height = 70.0;
          box_width = 400.0;
          cx = 960.0;
          cy = 961.0;
          output = "DP-1";
          rotation = 0.0;
          type = "login_box";
          settings = {
            background_color = "surface_variant";
            background_opacity = 0.88;
            background_radius = 12.0;
            center_password_text = false;
            input_opacity = 1.0;
            input_radius = 6.0;
            show_caps_lock = true;
            show_keyboard_layout = true;
            show_login_button = true;
            show_password_hint = true;
          };
        };
      };

      notification.position = "bottom_right";

      plugins.auto_update = false;

      osd = {
        position = "bottom_right";
        position_vertical = "bottom_right";
      };

      shell = {
        clipboard_enabled = true;
        corner_radius_scale = 0.0;
        screenshot.copy_to_clipboard = true;
        animation.enabled = false;
        launcher = {
          categories = false;
          show_icons = false;
        };
        panel = {
          clipboard_position = "bottom_left";
          control_center_placement = "floating";
          control_center_position = "bottom_left";
          launcher_position = "bottom_left";
          open_near_click_clipboard = true;
          open_near_click_launcher = true;
          open_near_click_session = true;
          polkit_position = "bottom_left";
          session_placement = "floating";
          session_position = "bottom_left";
          wallpaper_placement = "floating";
          wallpaper_position = "bottom_left";
        };
      };

      idle.behavior."screen-off" = {
        timeout = 600;
        action = "command";
        command = "${pkgs.wlopm}/bin/wlopm --off '*'";
        resume_command = "${pkgs.wlopm}/bin/wlopm --on '*'";
      };

      brightness = {
        enable_ddcutil = true;
        monitor.DP-1.backend = "ddcutil";
      };

      wallpaper = {
        directory = wallpaperDirectory;
        default.path = wallpaper;
        monitors.DP-1.path = wallpaper;
      };

      theme = {
        community_palette = "Monochrome";
        source = "community";
        templates = {
          enable_builtin_templates = true;
          builtin_ids = [
            "foot"
            "gtk3"
            "gtk4"
          ];
          community_ids = [
            "discord"
            "pywalfox-beta4"
            "yazi"
            "zathura"
          ];
          user = {
            foot_terminal_sequences = {
              input_path = "${templateRoot}/terminal-sequences";
              output_path = "${config.home.homeDirectory}/.cache/noctalia/terminal-sequences";
              post_hook = ''
                for terminal in /dev/pts/[0-9]*; do if [ -w "$terminal" ]; then cat "$HOME/.cache/noctalia/terminal-sequences" > "$terminal"; fi; done
              '';
            };
            labwc = {
              input_path = "${templateRoot}/labwc";
              output_path = "${config.home.homeDirectory}/.local/share/themes/noctalia/openbox-3/themerc";
              post_hook = "labwc --reconfigure";
            };
          };
        };
      };
    };
  };
}
