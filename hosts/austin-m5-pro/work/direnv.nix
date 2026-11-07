# Work-only direnv setup: auto-load the homelab dev shell under
# ~/brt-projects and ~/sparkai-projects.
#
# direnv itself stays the Homebrew install (zsh already runs `direnv hook
# zsh`). nix-direnv provides the `use flake` implementation and caches the
# shell so re-entry is fast.
#
# The whitelist uses `exact` (not `prefix`): a prefix whitelist would
# auto-trust any .envrc committed under those trees.
{ pkgs, ... }: {
  home-manager.users."austin.mills".home.file = {
    ".config/direnv/direnvrc".text = ''
      source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
    '';

    ".config/direnv/direnv.toml".text = ''
      [global]
      hide_env_diff = true

      [whitelist]
      exact = ["/Users/austin.mills/brt-projects/.envrc", "/Users/austin.mills/sparkai-projects/.envrc", "/Users/austin.mills/homelab/nix/.envrc"]
    '';

    "brt-projects/.envrc".text = ''
      use flake /Users/austin.mills/homelab/nix
      watch_file /Users/austin.mills/homelab/nix/flake.lock /Users/austin.mills/homelab/nix/shared/devshell.nix /Users/austin.mills/homelab/nix/shared/packages.nix /Users/austin.mills/homelab/nix/shared/env.nix
    '';

    "sparkai-projects/.envrc".text = ''
      use flake /Users/austin.mills/homelab/nix
      watch_file /Users/austin.mills/homelab/nix/flake.lock /Users/austin.mills/homelab/nix/shared/devshell.nix /Users/austin.mills/homelab/nix/shared/packages.nix /Users/austin.mills/homelab/nix/shared/env.nix
    '';

    # act (local GitHub Actions): pinned runner images, amd64 under
    # emulation, and the Zscaler CA bundle + cert env vars so TLS inside job
    # containers verifies. act's .actrc splits each line on the first
    # whitespace only, so the space in --container-options is fine.
    ".actrc".text = ''
      -P ubuntu-latest=catthehacker/ubuntu:act-latest
      -P ubuntu-24.04=catthehacker/ubuntu:act-24.04
      -P ubuntu-22.04=catthehacker/ubuntu:act-22.04
      --container-architecture linux/amd64
      --container-options -v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro
      --env NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
      --env SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    '';

    # kind cluster config for Zscaler: mount the macOS CA bundle (which
    # already includes the Zscaler root) into the node so containerd image
    # pulls verify. Docker Desktop resolves the /etc/ssl symlink and shares
    # the real file. Usage (own kubeconfig, so ~/.kube/config and its current
    # context are never touched):
    #   kind create cluster --name <task> --image kindest/node:<version> \
    #     --config ~/.config/kind/cluster.yaml --kubeconfig /tmp/kind-<task>.kubeconfig
    ".config/kind/cluster.yaml".text = ''
      kind: Cluster
      apiVersion: kind.x-k8s.io/v1alpha4
      nodes:
      - role: control-plane
        extraMounts:
        - hostPath: /etc/ssl/certs/ca-certificates.crt
          containerPath: /etc/ssl/certs/ca-certificates.crt
          readOnly: true
    '';
  };
}
