# Interactive installer for the NixOS hosts in this repo (run as root on the installer ISO).
#
#   install-host            pick a host from the menu
#   install-host gaming-pc  install that host directly
#
# The repo and the heimdall input are private, so fetching needs GitHub access:
#   - SSH in with agent forwarding: ssh -A root@<installer-ip>, or
#   - GITHUB_TOKEN=<token> install-host
#
# A host is listed when hosts/<dir>/flake.nix has a nixosConfiguration with disko disks.
# If hosts/<dir>/install-hook.sh exists it runs after the disks are mounted at /mnt
# and before nixos-install:  install-hook.sh <host> <repo-dir>

REPO_URL="${REPO_URL:-git@github.com:Austin37AF/nix-config.git}"
REPO_DIR="${REPO_DIR:-/root/nix-config}"

if [[ $EUID -ne 0 ]]; then
  exec sudo --preserve-env=SSH_AUTH_SOCK,GITHUB_TOKEN,REPO_URL,REPO_DIR "$0" "$@"
fi

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  export GIT_CONFIG_COUNT=2
  export GIT_CONFIG_KEY_0="url.https://x-access-token:${GITHUB_TOKEN}@github.com/.insteadOf"
  export GIT_CONFIG_VALUE_0="git@github.com:"
  export GIT_CONFIG_KEY_1="url.https://x-access-token:${GITHUB_TOKEN}@github.com/.insteadOf"
  export GIT_CONFIG_VALUE_1="ssh://git@github.com/"
fi
export NIX_CONFIG="experimental-features = nix-command flakes
accept-flake-config = false"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "Cloning $REPO_URL into $REPO_DIR ..."
  if ! git clone "$REPO_URL" "$REPO_DIR"; then
    echo "Clone failed. Reconnect with 'ssh -A root@<installer-ip>' or run: GITHUB_TOKEN=<token> install-host" >&2
    exit 1
  fi
else
  echo "Using existing checkout $REPO_DIR ($(git -C "$REPO_DIR" log -1 --format='%h %s'))"
fi
cd "$REPO_DIR"

# "dir host" pairs for every installable host
declare -a choices=()
echo "Scanning hosts/ for installable machines..."
for flake in hosts/*/flake.nix; do
  dir=$(basename "$(dirname "$flake")")
  grep -q nixosConfigurations "$flake" || continue
  # shellcheck disable=SC2016
  names=$(nix eval --json "./hosts/$dir#nixosConfigurations" \
    --apply 'cs: builtins.filter (n: (cs.${n}.config.disko.devices.disk or {}) != {}) (builtins.attrNames cs)' 2>/dev/null) \
    || { echo "  (skipping hosts/$dir: failed to evaluate)"; continue; }
  for host in $(jq -r '.[]' <<<"$names"); do
    choices+=("$dir $host")
  done
done
[[ ${#choices[@]} -gt 0 ]] || { echo "No installable hosts found." >&2; exit 1; }

target="${1:-}"
selection=""
if [[ -n "$target" ]]; then
  for c in "${choices[@]}"; do [[ "${c#* }" == "$target" ]] && selection="$c"; done
  [[ -n "$selection" ]] || { echo "Unknown host: $target" >&2; exit 1; }
else
  echo
  PS3="Install which host? "
  select c in "${choices[@]}"; do
    [[ -n "$c" ]] && { selection="$c"; break; }
  done
fi
dir="${selection% *}"
host="${selection#* }"
flake="./hosts/$dir#$host"

disks=$(nix eval --json "$flake.config.disko.devices.disk" --apply 'ds: map (d: d.device) (builtins.attrValues ds)' | jq -r 'join(" ")')
echo
lsblk -o NAME,SIZE,MODEL,TRAN,LABEL,FSTYPE
echo
echo "About to install $host (hosts/$dir) and WIPE: $disks"
read -r -p "Type the host name to continue: " confirm
[[ "$confirm" == "$host" ]] || { echo "Aborted."; exit 1; }

disko --mode destroy,format,mount --yes-wipe-all-disks --flake "$flake"

hw="hosts/$dir/hardware-configuration.nix"
if [[ -f "$hw" ]]; then
  read -r -p "Regenerate $hw for this machine? [y/N] " regen
  if [[ "$regen" == [yY]* ]]; then
    nixos-generate-config --no-filesystems --root /mnt --show-hardware-config > "$hw"
    echo "Wrote $hw (commit and push it after install)."
  fi
fi

if [[ -x "hosts/$dir/install-hook.sh" ]]; then
  echo "Running hosts/$dir/install-hook.sh ..."
  "hosts/$dir/install-hook.sh" "$host" "$REPO_DIR"
fi

nixos-install --flake "$flake" --no-root-passwd --no-channel-copy

cat <<MSG

Done: $host is installed. Next steps:
  1. reboot (remove the USB stick)
  2. Clone this repo to ~/homelab/nix on the new machine and run: rebuild
     (if you regenerated $hw, commit and push it first: git -C $REPO_DIR status)
MSG
