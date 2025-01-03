Avunu NixOS-WSL config for local development. Apply within [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) with:
```bash
nixos-rebuild switch --flake github:Avunu/nixos-wsl#nixos --refresh --impure
```
IF it fails, try:
```powershell
wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery
```
then retry the above command.
