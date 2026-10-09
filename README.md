# NixOS WSL

A modular NixOS configuration for [NixOS-WSL](https://github.com/nix-community/NixOS-WSL).

## Quick Start

First, install a [NixOS-WSL instance with the default configuration](https://nix-community.github.io/NixOS-WSL/install.html).

Then, rebase your local config based on this repository (run in your NixOS-WSL instance):

```bash
curl -fsSL https://raw.githubusercontent.com/Avunu/nixos-wsl/main/local/flake.nix | \
  sudo install -Dm644 /dev/stdin /etc/nixos/flake.nix && \
  sudo nixos-rebuild switch --flake /etc/nixos#nixos --impure
```

## Subsequent Updates

```bash
sudo nixos-rebuild switch --flake github:Avunu/nixos-wsl#nixos --refresh --impure
```

`system-upgrade` does the same from `/etc/nixos`, and only rebuilds if the flake lock moved. A daily timer runs it too.

## Development

```bash
nix develop                    # nixfmt, prek, and the pre-commit hooks
nix flake check                # eval of the example host, plus the hooks
nix build .#system-upgrade     # the upgrade script on its own
nix fmt
```

`.github/workflows/checks.yml` runs `nix flake check` on every pull request and push to `main`. Dependabot keeps the flake inputs and the pinned action SHAs current.

## Recovery

If a rebuild fails, recover with:

```powershell
wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery
```

Then retry the rebuild command.
