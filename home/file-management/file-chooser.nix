{
  lib,
  pkgs,
  ...
}:

let
  yaziWrapper = pkgs.writeShellApplication {
    name = "yazi-file-chooser";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.foot
      pkgs.yazi
    ];
    text = ''
      if (( $# != 6 )); then
        echo "usage: yazi-file-chooser MULTIPLE DIRECTORY SAVE PATH OUTPUT LOGLEVEL" >&2
        exit 2
      fi

      multiple=$1
      directory=$2
      save=$3
      start_path=$4
      output_file=$5
      cwd_file="$output_file.cwd"

      chooser_args=(--chooser-file="$output_file")
      title="Choose a file"

      if [[ $directory == 1 ]]; then
        : > "$cwd_file"
        trap 'rm -f -- "$cwd_file"' EXIT
        chooser_args+=(--cwd-file="$cwd_file")
        title="Choose a folder"
      elif [[ $save == 1 ]]; then
        title="Save a file"
      fi

      chooser_args+=("$start_path")

      status=0
      foot \
        --app-id=yazi-file-chooser \
        --title="$title" \
        yazi "''${chooser_args[@]}" || status=$?

      if [[ $directory == 1 ]]; then
        if [[ ! -s $output_file && -s $cwd_file ]]; then
          cp -- "$cwd_file" "$output_file"
        fi
      fi

      if [[ $multiple != 1 && -s $output_file ]]; then
        first_selection=
        IFS= read -r first_selection < "$output_file" || true
        printf '%s\n' "$first_selection" > "$output_file"
      fi

      exit "$status"
    '';
  };
in
{
  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${lib.getExe yaziWrapper}
    create_help_file=1
    default_dir=$HOME
    open_mode=suggested
    save_mode=suggested
  '';

  programs.firefox.policies.Preferences."widget.use-xdg-desktop-portal.file-picker" = {
    Value = 1;
    Status = "locked";
  };
}
