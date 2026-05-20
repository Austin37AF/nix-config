#!/usr/bin/env bash
set -euo pipefail

# Flash NixOS ISO to USB drive safely
# Usage: ./scripts/flash-usb.sh [iso-path]

ISO_PATH="${1:-}"

# Find ISO file
if [[ -n "$ISO_PATH" && -f "$ISO_PATH" ]]; then
    ISO_FILE="$ISO_PATH"
elif [[ -d "./iso" ]]; then
    ISO_FILE=$(find ./iso -name "nixos-*.iso" -type f 2>/dev/null | head -1)
elif [[ -d "./result/iso" ]]; then
    ISO_FILE=$(find ./result/iso -name "nixos-*.iso" -type f 2>/dev/null | head -1)
else
    # Check common download locations
    ISO_FILE=$(find ~/Downloads -name "nixos-*.iso" -type f -mtime -1 2>/dev/null | head -1)
fi

if [[ -z "$ISO_FILE" || ! -f "$ISO_FILE" ]]; then
    echo "❌ ISO not found!"
    echo ""
    echo "Options:"
    echo "  1. Build locally:    nix build .#k8s-installer-iso"
    echo "  2. Download from:    https://github.com/Austin37AF/nix-config/actions"
    echo "  3. Specify path:     ./scripts/flash-usb.sh /path/to/nixos.iso"
    exit 1
fi

echo "📀 ISO found: $ISO_FILE"
echo "   Size: $(du -h "$ISO_FILE" | cut -f1)"
echo ""

# List disks
echo "💾 Available disks:"
echo "─────────────────────────────────────────────────────────"
diskutil list external physical 2>/dev/null || diskutil list
echo "─────────────────────────────────────────────────────────"
echo ""

# Prompt for disk
read -p "Enter disk number to flash (e.g., 2 for /dev/disk2): " DISK_NUM

if [[ -z "$DISK_NUM" ]]; then
    echo "❌ No disk number provided"
    exit 1
fi

DISK="/dev/disk${DISK_NUM}"
RDISK="/dev/rdisk${DISK_NUM}"

# Verify disk exists
if ! diskutil info "$DISK" &>/dev/null; then
    echo "❌ Disk $DISK does not exist"
    exit 1
fi

# Get disk info for confirmation
DISK_SIZE=$(diskutil info "$DISK" | grep "Disk Size" | awk -F: '{print $2}' | xargs)
DISK_NAME=$(diskutil info "$DISK" | grep "Device / Media Name" | awk -F: '{print $2}' | xargs)

echo ""
echo "⚠️  WARNING: This will ERASE ALL DATA on:"
echo "   Disk:  $DISK"
echo "   Name:  $DISK_NAME"
echo "   Size:  $DISK_SIZE"
echo ""

read -p "Type 'yes' to confirm: " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "❌ Aborted"
    exit 1
fi

echo ""
echo "🔄 Unmounting $DISK..."
diskutil unmountDisk "$DISK"

echo "🔥 Flashing ISO to $RDISK (this may take a few minutes)..."
echo "   You may be prompted for your password."
echo ""

sudo dd if="$ISO_FILE" of="$RDISK" bs=4m status=progress

echo ""
echo "🔄 Ejecting $DISK..."
diskutil eject "$DISK"

echo ""
echo "✅ Done! USB is ready."
echo "   Boot your Mac Mini while holding the Option key to select the USB."
