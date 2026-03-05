# NixOS WSL

A modular NixOS configuration for [NixOS-WSL](https://github.com/nix-community/NixOS-WSL).

## Quick Start

Bootstrap a new WSL instance by pulling the local config into place and rebuilding:

```bash
curl -fsSL https://raw.githubusercontent.com/Avunu/nixos-wsl/main/local/flake.nix | \
  sudo install -Dm644 /dev/stdin /etc/nixos/flake.nix && \
  sudo nixos-rebuild switch --flake /etc/nixos#nixos --impure
```

## Subsequent Updates

```bash
sudo nixos-rebuild switch --flake github:Avunu/nixos-wsl#nixos --refresh --impure
```

## Recovery

If a rebuild fails, recover with:

```powershell
wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery
```

Then retry the rebuild command.
