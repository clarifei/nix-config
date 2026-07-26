{
  lib,
  pkgs,
  ...
}:

let
  yaziWrapper = pkgs.writeShellApplication {
    name = "yazi-file-chooser";
    excludeShellChecks = [ "SC2053" ];
    runtimeInputs = [
      pkgs.coreutils
      pkgs.file
      pkgs.foot
      pkgs.libnotify
      pkgs.yazi
    ];
    text = ''
      if (( $# < 6 || $# > 7 )); then
        echo "usage: yazi-file-chooser MULTIPLE DIRECTORY SAVE PATH OUTPUT LOGLEVEL [FILTERS]" >&2
        exit 2
      fi

      multiple=$1
      directory=$2
      save=$3
      start_path=$4
      output_file=$5
      filters_file=''${7:-}
      cwd_file="$output_file.cwd"

      filter_names=()
      filter_types=()
      filter_patterns=()
      has_glob_rules=0

      if [[ -n $filters_file && -s $filters_file ]]; then
        mapfile -d "" -t filter_records < "$filters_file"
        record_index=0

        while (( record_index < ''${#filter_records[@]} )); do
          marker="''${filter_records[$record_index]}"
          ((record_index += 1))

          case "$marker" in
            filter)
              filter_names+=("''${filter_records[$record_index]}")
              ((record_index += 1))
              ;;
            rule)
              rule_type="''${filter_records[$record_index]}"
              rule_pattern="''${filter_records[$((record_index + 1))]}"
              filter_types+=("$rule_type")
              filter_patterns+=("$rule_pattern")
              [[ $rule_type != 0 ]] || has_glob_rules=1
              ((record_index += 2))
              ;;
            end-filter) ;;
            end) break ;;
            *)
              echo "invalid filter metadata marker: $marker" >&2
              exit 2
              ;;
          esac
        done
      fi

      filter_summary=
      for filter_name in "''${filter_names[@]}"; do
        [[ -z $filter_summary ]] || filter_summary+=", "
        filter_summary+="$filter_name"
      done
      if (( ''${#filter_summary} > 80 )); then
        filter_summary="''${filter_summary:0:77}..."
      fi

      selection_matches() {
        local selected=$1
        local filename mime rule_index rule_type rule_pattern

        if [[ $directory == 1 ]]; then
          [[ -d $selected ]]
          return
        fi

        [[ ( -e $selected || -L $selected ) && ! -d $selected ]] || return 1
        (( ''${#filter_types[@]} > 0 )) || return 0

        filename=$(basename -- "$selected")
        mime=

        if [[ $save == 1 && $has_glob_rules == 0 ]]; then
          # The file contents do not exist yet, so MIME-only save filters
          # cannot be validated reliably from the placeholder file.
          return 0
        fi

        for ((rule_index = 0; rule_index < ''${#filter_types[@]}; rule_index++)); do
          rule_type="''${filter_types[$rule_index]}"
          rule_pattern="''${filter_patterns[$rule_index]}"

          if [[ $rule_type == 0 && $filename == $rule_pattern ]]; then
            return 0
          fi

          if [[ $save != 1 && $rule_type == 1 ]]; then
            if [[ -z $mime ]]; then
              mime=$(file --brief --dereference --mime-type -- "$selected" 2>/dev/null) || mime=
            fi
            if [[ $mime == $rule_pattern ]]; then
              return 0
            fi
          fi
        done

        return 1
      }

      selections_are_valid() {
        local selected
        invalid_selection=

        while IFS= read -r selected || [[ -n $selected ]]; do
          [[ -n $selected ]] || continue
          if ! selection_matches "$selected"; then
            invalid_selection=$selected
            return 1
          fi
        done < "$output_file"

        return 0
      }

      base_title="Choose a file"

      if [[ $directory == 1 ]]; then
        trap 'rm -f -- "$cwd_file"' EXIT
        base_title="Choose a folder"
      elif [[ $save == 1 ]]; then
        base_title="Save a file"
      elif [[ $multiple == 1 ]]; then
        base_title="Choose files"
      fi

      while true; do
        chooser_args=(--chooser-file="$output_file")
        title=$base_title

        : > "$output_file"
        if [[ $directory == 1 ]]; then
          : > "$cwd_file"
          chooser_args+=(--cwd-file="$cwd_file")
        elif [[ -n $filter_summary ]]; then
          title+=" - $filter_summary"
        fi

        chooser_args+=("$start_path")

        status=0
        foot \
          --app-id=yazi-file-chooser \
          --title="$title" \
          yazi "''${chooser_args[@]}" || status=$?

        if (( status != 0 )); then
          exit "$status"
        fi

        if [[ $directory == 1 && ! -s $output_file && -s $cwd_file ]]; then
          cp -- "$cwd_file" "$output_file"
        fi

        if [[ $multiple != 1 && -s $output_file ]]; then
          first_selection=
          IFS= read -r first_selection < "$output_file" || true
          printf '%s\n' "$first_selection" > "$output_file"
        fi

        [[ -s $output_file ]] || exit 0

        if selections_are_valid; then
          exit 0
        fi

        invalid_name=$(basename -- "$invalid_selection")
        if [[ $directory == 1 ]]; then
          expected="a folder"
        elif [[ -n $filter_summary ]]; then
          expected=$filter_summary
        else
          expected="a file"
        fi

        notify-send \
          --app-name="Yazi File Chooser" \
          --urgency=critical \
          "Selection not allowed" \
          "'$invalid_name' does not match: $expected" || true

        invalid_parent=$(dirname -- "$invalid_selection")
        [[ ! -d $invalid_parent ]] || start_path=$invalid_parent
      done
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
