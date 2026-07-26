{
  coreutils,
  foot,
  fzf,
  lib,
  writeShellApplication,
}:

let
  chooserTui = writeShellApplication {
    name = "xdpw-foot-chooser-tui";
    runtimeInputs = [ fzf ];
    text = ''
      if (( $# != 2 )); then
        exit 2
      fi

      candidates=$1
      selection_file=$2

      selection=
      if selection=$(
        fzf \
          --no-multi \
          --layout=reverse \
          --border \
          --info=inline-right \
          --prompt='Share: ' \
          --pointer='>' \
          --marker='+' \
          --color='16,border:8,prompt:4,pointer:6,marker:2,hl:3,hl+:3' \
          < "$candidates"
      ); then
        printf '%s\n' "$selection" > "$selection_file"
      fi
    '';
  };
in
writeShellApplication {
  name = "xdpw-foot-chooser";
  runtimeInputs = [
    coreutils
    foot
  ];
  text = ''
    chooser_runtime=''${XDG_RUNTIME_DIR:-/tmp}
    chooser_dir=$(mktemp --directory --tmpdir="$chooser_runtime" xdpw-foot-chooser.XXXXXX)
    candidates="$chooser_dir/candidates"
    selection_file="$chooser_dir/selection"

    cleanup() {
      rm -f -- "$candidates" "$selection_file"
      rmdir -- "$chooser_dir" 2>/dev/null || true
    }
    trap cleanup EXIT
    trap 'exit 130' HUP INT TERM

    cat > "$candidates"
    [[ -s $candidates ]] || exit 0

    foot \
      --app-id=xdpw-foot-chooser \
      --title='Choose what to share' \
      --override=main.initial-window-size-pixels=900x500 \
      ${lib.getExe chooserTui} "$candidates" "$selection_file" \
      >/dev/null || true

    if [[ -s $selection_file ]]; then
      head --lines=1 -- "$selection_file"
    fi
  '';
}
