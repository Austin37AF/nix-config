#!/usr/bin/env bash
set -euo pipefail

# Update flake inputs per machine. Each host in hosts/ has its own flake.lock, so
# updating one never moves another.
#
# Usage: ./scripts/update.sh <host>... [-- <nix flake update args>]
#   ./scripts/update.sh gaming-pc                 # all inputs of hosts/gaming-pc
#   ./scripts/update.sh k8s -- nixpkgs            # only nixpkgs for the cluster
#   ./scripts/update.sh all                       # every host + the root flake

cd "$(dirname "$0")/.."

hosts=()
while [[ $# -gt 0 && "$1" != "--" ]]; do hosts+=("$1"); shift; done
[[ "${1:-}" == "--" ]] && shift

if [[ ${#hosts[@]} -eq 0 ]]; then
    echo "Usage: $0 <host>...|all [-- <inputs>]"
    echo "Hosts: $(cd hosts && ls -d */ | tr -d / | tr '\n' ' ')"
    exit 1
fi
if [[ "${hosts[0]}" == "all" ]]; then
    mapfile -t hosts < <(cd hosts && ls -d */ | tr -d /)
    echo "== root"
    nix flake update --flake . "$@"
fi

for h in "${hosts[@]}"; do
    [[ -f "hosts/$h/flake.nix" ]] || { echo "No such host: $h"; exit 1; }
    echo "== $h"
    nix flake update --flake "./hosts/$h" "$@"
done
