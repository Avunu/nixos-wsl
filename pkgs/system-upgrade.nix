# The `system-upgrade` command: update /etc/nixos's lock and rebuild if it moved.
# Run by hand or by the daily timer in flake.nix.
#
# Copied from nixos-dev-host (pkgs/system-upgrade.nix), which is the reference
# for this script; keep the two in step by hand.
#
# Only the local-flake shape is kept here: this machine's configuration lives in
# /etc/nixos, and nothing is pulled from a GitHub revision.
{
  pkgs,
  flake ? "/etc/nixos",
  # Extra flags for nixos-rebuild, e.g. "--impure". Shell words, unquoted.
  extraFlags ? "",
}:
let
  ref = pkgs.lib.escapeShellArg flake;
in
pkgs.writeShellApplication {
  name = "system-upgrade";
  runtimeInputs = with pkgs; [
    coreutils
    git
    jq
    nix
    nixos-rebuild
  ];
  text = ''
    if [ "$(id -u)" -ne 0 ]; then
      exec sudo "$0" "$@"
    fi

    cd ${ref}

    # The guard that makes a daily timer cheap. `nix flake update` on a
    # machine tracking nixos-unstable moves the lock most days but not every
    # day, and a rebuild that finds nothing to do still costs a full
    # evaluation, a store scan and a generation. Comparing the lock before
    # and after turns "rebuild daily" into "rebuild when something changed".
    BEFORE=$(sha256sum flake.lock 2>/dev/null || echo "")
    nix flake update --flake ${ref}
    AFTER=$(sha256sum flake.lock 2>/dev/null || echo "")

    if [ "$BEFORE" = "$AFTER" ]; then
      echo "Flake lock unchanged, skipping rebuild" >&2
      exit 0
    fi

    nixos-rebuild switch --flake ${ref} ${extraFlags}

    echo "Upgrade applied. A reboot is not taken automatically; run one when it suits you." >&2
  '';
}
