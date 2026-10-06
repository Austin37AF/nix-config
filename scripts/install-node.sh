#!/usr/bin/env bash
set -euo pipefail

# Install a K8s node with nixos-anywhere, seeding its pre-generated SSH host key
# so sops-nix can decrypt secrets/k8s.yaml (k3s token) on first boot.
#
# Usage: ./scripts/install-node.sh <node-name> <installer-ip>
#   e.g. ./scripts/install-node.sh k8s-server-1 10.17.17.50
#
# The target must be booted from the k8s installer ISO (root SSH with your key).
# WARNING: wipes the disk configured in modules/kubernetes/cluster-config.nix.

NODE="${1:-}"
IP="${2:-}"
cd "$(dirname "$0")/.."

if [[ -z "$NODE" || -z "$IP" ]]; then
    echo "Usage: $0 <node-name> <installer-ip>"
    echo "Nodes: $(nix eval --raw --apply 'n: builtins.concatStringsSep " " (builtins.attrNames n)' --file modules/kubernetes/cluster-config.nix nodes)"
    exit 1
fi

DISK=$(nix eval --raw --file modules/kubernetes/cluster-config.nix \
    --apply "c: if c.nodes ? \"$NODE\" then c.nodes.\"$NODE\".disk or c.defaultDisk else throw \"unknown node\"" 2>/dev/null) \
    || { echo "Unknown node: $NODE"; exit 1; }

export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
SOPS="nix shell nixpkgs#sops -c sops"

EXTRA=$(mktemp -d)
trap 'rm -rf "$EXTRA"' EXIT
install -d -m 755 "$EXTRA/etc/ssh"
(umask 077 && $SOPS -d --extract "[\"$NODE\"]" secrets/host-keys.yaml > "$EXTRA/etc/ssh/ssh_host_ed25519_key")
ssh-keygen -y -f "$EXTRA/etc/ssh/ssh_host_ed25519_key" > "$EXTRA/etc/ssh/ssh_host_ed25519_key.pub"
chmod 644 "$EXTRA/etc/ssh/ssh_host_ed25519_key.pub"

echo "Disks on $IP:"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$IP" lsblk -d -o NAME,SIZE,MODEL,TRAN
echo
echo "About to install $NODE to $IP and WIPE $DISK."
read -r -p "Type the node name to continue: " CONFIRM
[[ "$CONFIRM" == "$NODE" ]] || { echo "Aborted."; exit 1; }

nix run github:nix-community/nixos-anywhere -- \
    --flake ".#$NODE" \
    --target-host "root@$IP" \
    --extra-files "$EXTRA" \
    --build-on remote

echo
echo "Done. $NODE will reboot to its static IP; SSH: ssh k8sadmin@<node-ip>"
