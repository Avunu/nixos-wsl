# NixOS WSL

A modular NixOS configuration for [NixOS-WSL](https://github.com/nix-community/NixOS-WSL).

## Quick Start

First, install a [NixOS-WSL instance with the default configuration](https://nix-community.github.io/NixOS-WSL/install.html).

Then, switch it to this repository's configuration (run in your NixOS-WSL instance):

```bash
sudo nixos-rebuild switch --flake github:Avunu/nixos-wsl#nixos --refresh --impure
```

There is no local flake: the configuration and its pinned inputs live here, and `/etc/nixos` is not used.

## Updates

Dependabot moves the flake inputs in this repository. Once a change lands on `main`, a daily timer on each machine runs `system-upgrade`, which rebuilds from `github:Avunu/nixos-wsl#nixos` only when the repository's revision differs from the one the running system was built from. Run `system-upgrade` to pull it in sooner, or rerun the command above.

## Development

```bash
nix develop                    # nixfmt, prek, and the pre-commit hooks
nix flake check                # eval of the `nixos` host, plus the hooks
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
