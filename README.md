# nixos config

## apply

from the repo root:

```bash
nh os switch . -H "$(hostname)" --accept-flake-config
```

dry run:

```bash
nh os switch . -H "$(hostname)" --dry --no-nom --accept-flake-config
```

rollback:

```bash
nh os rollback
```

## new machine

copy the template, generate the hardware config, edit `host.nix`, then apply:

```bash
cp -a hosts/nixos hosts/<hostname>
sudo nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware-configuration.nix
$EDITOR hosts/<hostname>/host.nix
nh os switch . -H <hostname> --accept-flake-config
```

set these values in `host.nix`:

* `system`
* `username`
* `cpu`

optional:

* `graphics = "nvidia"` for nvidia systems
* `ddcutil = true` when monitor ddc control is available

host directories are discovered automatically by the flake.
