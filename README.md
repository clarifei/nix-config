# NixOS Config

## Apply

Run from this repository:

```bash
nh os switch . -H "$(hostname)"
```

Dry-run first:

```bash
nh os switch . -H "$(hostname)" --dry --no-nom
```

Rollback:

```bash
nh os rollback
```

## New Machine

Copy the host template, generate hardware config, then edit only `host.nix`:

```bash
cp -a hosts/nixos hosts/<hostname>
sudo nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware-configuration.nix
$EDITOR hosts/<hostname>/host.nix
nh os switch . -H <hostname>
```

Set `system`, `username`, and `cpu` in `host.nix`. Add `graphics = "nvidia"`
only for NVIDIA hosts and `ddcutil = true` only when monitor DDC control is
available. The flake discovers host directories automatically.
