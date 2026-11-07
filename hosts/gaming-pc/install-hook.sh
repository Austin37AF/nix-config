#!/usr/bin/env bash
# Run by install-host after disko mounts the OS disk at /mnt, before nixos-install.
# The games disk is not in disko: format it only if no filesystem labeled "games" exists,
# so reinstalling keeps the games. Override the disk with GAMES_DISK=/dev/...
set -euo pipefail
GAMES_DISK="${GAMES_DISK:-/dev/nvme0n1}"

if [[ -e /dev/disk/by-label/games ]]; then
  echo "Games disk: filesystem labeled 'games' exists and will be KEPT."
  exit 0
fi
echo "Games disk: no filesystem labeled 'games' found."
read -r -p "Format $GAMES_DISK as ext4 (label games)? This WIPES it. [y/N] " ok
if [[ "$ok" == [yY]* ]]; then
  lsblk -nrpo NAME "$GAMES_DISK" | tac | xargs wipefs -af
  mkfs.ext4 -F -L games "$GAMES_DISK"
else
  echo "Skipped; /games mounts with nofail until a disk labeled 'games' exists."
fi
