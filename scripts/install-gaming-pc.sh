#!/usr/bin/env bash
set -euo pipefail

# Install the gaming PC with nixos-anywhere.
#
# Usage: ./scripts/install-gaming-pc.sh <installer-ip>
#   e.g. ./scripts/install-gaming-pc.sh 192.168.1.50
#
# The target must be booted from the installer ISO (root SSH with your key).
# WARNING: wipes the OS disk configured in hosts/gaming-pc (via disko).
# The games disk is not in disko: it is only formatted if no filesystem labeled
# "games" exists yet, so reinstalling keeps it. Override with GAMES_DISK=/dev/...

GAMES_DISK="${GAMES_DISK:-/dev/nvme0n1}"

IP="${1:-}"
cd "$(dirname "$0")/.."

if [[ -z "$IP" ]]; then
    echo "Usage: $0 <installer-ip>"
    exit 1
fi

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
remote() { ssh "${SSH_OPTS[@]}" "root@$IP" "$@"; }

OS_DISK=$(nix eval --raw ./hosts/gaming-pc#nixosConfigurations.gaming-pc.config.disko.devices.disk.main.device)

echo "Disks on $IP:"
remote lsblk -o NAME,SIZE,MODEL,TRAN,LABEL,FSTYPE
echo

if remote test -e /dev/disk/by-label/games; then
    FORMAT_GAMES=0
    echo "Games disk: filesystem labeled 'games' exists and will be KEPT."
    WIPE="$OS_DISK"
else
    FORMAT_GAMES=1
    echo "Games disk: no filesystem labeled 'games' found; $GAMES_DISK will be formatted (ext4, label games)."
    WIPE="$OS_DISK and $GAMES_DISK"
fi

echo
echo "About to install gaming-pc to $IP and WIPE: $WIPE"
read -r -p "Type gaming-pc to continue: " CONFIRM
[[ "$CONFIRM" == "gaming-pc" ]] || { echo "Aborted."; exit 1; }

remote "lsblk -nrpo NAME $OS_DISK | tac | xargs wipefs -af && dd if=/dev/zero of=$OS_DISK bs=1M count=1100 conv=fsync status=none"

# --phases skips the final reboot so the games disk can be formatted first.
nix run github:nix-community/nixos-anywhere -- \
    --flake "./hosts/gaming-pc#gaming-pc" \
    --target-host "root@$IP" \
    --build-on remote \
    --phases kexec,disko,install \
    --generate-hardware-config nixos-generate-config ./hosts/gaming-pc/hardware-configuration.nix

if [[ "$FORMAT_GAMES" == 1 ]]; then
    remote "lsblk -nrpo NAME $GAMES_DISK | tac | xargs wipefs -af"
    remote mkfs.ext4 -F -L games "$GAMES_DISK"
fi

remote reboot || true

cat <<MSG

Done. The PC is rebooting into NixOS. Next steps:
  1. Commit the generated hosts/gaming-pc/hardware-configuration.nix.
  2. Log in as austin / changeme and run: passwd
  3. Give the PC a GitHub SSH key and clone this repo to ~/homelab/nix
     (it has a private git+ssh heimdall input).
  4. Run: rebuild
  5. Point the Steam / Lutris libraries at /games.
MSG
