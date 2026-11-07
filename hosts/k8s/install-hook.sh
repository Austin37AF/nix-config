#!/usr/bin/env bash
# Run by install-host after disko mounts the disk at /mnt, before nixos-install.
# Seeds the node's pre-generated SSH host key (secrets/host-keys.yaml) so sops-nix can
# decrypt secrets/k8s.yaml (k3s token) on first boot. Needs the admin age key:
# set SOPS_AGE_KEY_FILE, copy it to /root/age-key.txt, or paste it when asked.
set -euo pipefail
HOST="$1"
REPO_DIR="$2"

key_file="${SOPS_AGE_KEY_FILE:-/root/age-key.txt}"
if [[ ! -f "$key_file" ]]; then
  read -r -s -p "Paste the admin age secret key (AGE-SECRET-KEY-...), or Enter to skip: " age_key
  echo
  if [[ -z "$age_key" ]]; then
    echo "WARNING: no host key seeded; $HOST won't decrypt the k3s token until it's added to .sops.yaml." >&2
    read -r -p "Continue anyway? [y/N] " ok
    [[ "$ok" == [yY]* ]] || exit 1
    exit 0
  fi
  key_file=$(mktemp)
  trap 'rm -f "$key_file"' EXIT
  printf '%s\n' "$age_key" > "$key_file"
fi

install -d -m 755 /mnt/etc/ssh
(umask 077 && SOPS_AGE_KEY_FILE="$key_file" sops -d --extract "[\"$HOST\"]" \
  "$REPO_DIR/hosts/k8s/secrets/host-keys.yaml" > /mnt/etc/ssh/ssh_host_ed25519_key)
ssh-keygen -y -f /mnt/etc/ssh/ssh_host_ed25519_key > /mnt/etc/ssh/ssh_host_ed25519_key.pub
chmod 644 /mnt/etc/ssh/ssh_host_ed25519_key.pub
echo "Seeded SSH host key for $HOST."
