# Nix Darwin Configuration

Declarative macOS system configuration using nix-darwin, nix-homebrew, and Home Manager.

## Structure

```
~/homelab/nix/
├── flake.nix                    # Entry point: machines, darwinConfigurations, devShells, nixosConfigurations
├── modules/
│   ├── common/
│   │   ├── home.nix             # Home Manager: git, powerline-go, shell config (all hosts)
│   │   ├── packages.nix         # Shared package lists: cli, dev, fonts
│   │   ├── env.nix              # Shared env vars, aliases, powerline config
│   │   └── zsh.nix              # zsh + rebuild aliases (nixos + darwin)
│   ├── darwin/
│   │   ├── default.nix          # System settings, defaults, activation
│   │   ├── packages.nix         # macOS GUI apps (vim, obsidian, rectangle, ...)
│   │   ├── homebrew.nix         # Homebrew brews and casks (all Macs)
│   │   ├── home.nix             # Darwin HM: ssh config, Devin Desktop editor settings merge
│   │   ├── devin/               # Devin CLI: AGENTS.md, mcp_config.json, config.json merge, permissions
│   │   ├── cert-pem.nix         # eMudhra response: prunes distrusted roots from /etc/ssl/cert.pem
│   │   └── zsh.nix              # Darwin-specific zsh
│   ├── devshell.nix             # `nix develop` dev shell (also loaded by direnv)
│   ├── hosts/work/              # Work-machine-only modules (imported by the work config)
│   │   ├── zscaler.nix          # Zscaler root in the Nix CA bundle + cert env vars
│   │   ├── zscaler-root.crt     # The Zscaler root cert
│   │   ├── homebrew.nix         # Work brews (gimme-aws-creds)
│   │   ├── direnv.nix           # direnv + nix-direnv, .envrc, .actrc, kind cluster.yaml
│   │   └── devin/               # Work Devin addendum + AGENTS.local.md/skills symlinks
│   ├── hosts/gaming-pc/         # NixOS gaming PC (Plasma 6, NVIDIA 580 legacy, Steam)
│   ├── local-ai/                # LM Studio + Zed (local LLM) config; not on k8s nodes
│   └── kubernetes/              # NixOS k8s cluster configs (nodes, disko, hardening)
├── scripts/                     # install-node.sh, install-gaming-pc.sh (nixos-anywhere wrappers)
├── secrets/                     # sops-encrypted k8s secrets
├── devbox.json                  # Cluster-management shell (sops, age, kubectl, helm, k9s)
└── .github/workflows/build-iso.yaml  # Builds the k8s installer ISO
```

Two hosts share the same machine: `austin-m5-pro` (work, adds `modules/hosts/work`)
and `austin-m5-pro-home` (personal, no work modules). Rebuild with `rebuild` /
`rebuild-home` (needs sudo).

## Quick Commands

```bash
rebuild                    # darwin-rebuild switch (work config); primes the SSH agent first so root can fetch the private heimdall input
rebuild-home               # switch to the personal config
dev                        # nix dev shell manually (outside direnv dirs)
nix flake update           # update all inputs
```

## Certificates / Zscaler (work)

- `security.pki.certificateFiles` appends `zscaler-root.crt` to the nixpkgs
  cacert bundle at `/etc/ssl/certs/ca-certificates.crt`; the same file is
  linked at `~/certs/bundle.crt` for tools that need a stable path
  (`http.sslCAInfo`, gcloud `custom_ca_certs_file`).
- `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS` and
  `NIX_SSL_CERT_FILE` all point at it (`modules/hosts/work/zscaler.nix`,
  `modules/common/env.nix`).
- `cert-pem.nix` (eMudhra compromise): every rebuild, an activation step
  removes distrusted roots (emSign ECC Root CA - G3, AAA Certificate Services)
  from `/etc/ssl/cert.pem`, keeping a backup at `/etc/ssl/cert.pem.orig`.
  It's a no-op once Apple ships a clean file.

## Devin (CLI + Desktop)

- `~/.config/devin/AGENTS.md`: global rules — base set (`modules/darwin/devin`)
  plus a work addendum (Zscaler, kubectl/helm/Atlantis guardrails,
  `modules/hosts/work/devin`).
- `mcp_config.json`: declarative user-scope MCP servers (Atlassian).
- `config.json`: **merged** on activation, not symlinked — Devin mutates it
  (approvals, keymap, hooks). Managed keys win, `permissions.allow/ask/deny`
  are unioned with existing, JSONC/non-JSON files are left alone. Managed
  settings include the Fusion default model and the permission lists. Note:
  removing an entry from the Nix lists does not remove it from the file.
- Per-repo `AGENTS.local.md` notes and `~/.config/devin/skills/*` are
  **out-of-store symlinks** into `modules/hosts/work/devin/` — edits apply
  without a rebuild. `AGENTS.local.md` is ignored globally via
  `programs.git.ignores`.
- Skills:

  | Skill | What it does |
  |---|---|
  | `chart-check` | Lint/render Helm charts like CI (helm template, unittest, kubeconform) |
  | `kyverno-test` | Test Kyverno policies on a throwaway kind cluster, then clean up |
  | `go-bump-release` | Bump a Go repo's version, PR, release, verify published binaries |
  | `ci-local` | Run a repo's GitHub Actions jobs locally with `act` |

- Permissions (in `modules/darwin/devin/default.nix`):
  - allow: read-only git, `nix eval/build/flake show|metadata|check`, `darwin-rebuild build`, `gh pr view/diff/checks`, terraform/tofu `fmt`/`validate`, `helm template/lint`, `pre-commit run`, `aws sts get-caller-identity`
  - ask: terraform/tofu `apply`/`destroy`, mutating kubectl, `helm install/upgrade/uninstall`
  - deny: `sudo`, `darwin-rebuild switch/activate`, `git push --force*`
  - Matching is on the start of the command only, so the cluster-safety rules in AGENTS.md are the real guard.
- `attribution = false`: no Devin trailer on commits/PRs.
- Devin Desktop's `settings.json` (formerly Windsurf) is also merged on
  activation (managed keys win; stays a regular file).
- To add a repo to the personal notes: drop a markdown file in
  `modules/hosts/work/devin/repos/` and add one line to `outOfStoreLinks` in
  `modules/hosts/work/devin/default.nix`.

## Work dev shell via direnv

- `.envrc` in `~/brt-projects` and `~/sparkai-projects` runs `use flake
  ~/homelab/nix`; nix-direnv caches the shell (second entry ~0.2s).
  `direnv.toml` whitelists those two exact paths only.
- The dev shell's interactive bits (aliases, completions, powerline prompt)
  are skipped when `DIRENV_IN_ENVRC` is set; env/PATH exports always apply.
- Agent shells don't run the direnv hook — use `direnv exec . <cmd>`.
- Outside those dirs: `dev` (alias for `nix develop`).

## kind (throwaway clusters)

- `kind` in the dev shell is wrapped to unset `DOCKER_DEFAULT_PLATFORM` so
  nodes run native arm64 (linux/amd64 emulation broke containerd).
- `~/.config/kind/cluster.yaml` mounts the Zscaler CA bundle into nodes:
  ```bash
  kind create cluster --name <task> --image kindest/node:<ver> \
    --config ~/.config/kind/cluster.yaml --kubeconfig /tmp/kind-<task>.kubeconfig
  kind delete cluster --name <task> --kubeconfig /tmp/kind-<task>.kubeconfig
  ```
- Keep a separate kubeconfig per cluster; never touch `docker-desktop`.
- `kind load` images must be arm64 (or multi-arch).

## act / local CI

- `act` runs GitHub Actions jobs locally; `~/.actrc` pins the catthehacker
  runner images, linux/amd64, and mounts the CA bundle + cert env vars so
  TLS inside job containers verifies behind Zscaler.
- Limits: runner image differs from GitHub's, jobs run emulated (slow), and
  auth/publish jobs (OIDC, GitHub App tokens, pushes, deploys) can't run
  locally — run `pull_request` jobs only, `--rm` containers.

## Local AI (`modules/local-ai`)

- LM Studio + Zed (Homebrew casks); Zed is configured against LM Studio's local server (Qwen3.6-27B) with a `pr-review` skill in `~/.agents/skills`.
- One-time model download (after launching LM Studio once): `lms get qwen/qwen3.6-27b --mlx --select` and pick the 6-bit quant.
- Day to day: `heimdall ai up | down | status`.

## Homelab Kubernetes Cluster (`modules/kubernetes`)

NixOS k3s cluster on Mac minis; full guide in [`modules/kubernetes/README.md`](modules/kubernetes/README.md).

```bash
devbox shell                        # repo root: sops, age, kubectl, helm, k9s
sops secrets/k8s.yaml               # edit secrets
nix build .#k8s-installer-iso       # installer ISO (CI also publishes it to a rolling release)
nix run .#deploy                    # deploy all nodes (or: heimdall cluster update)
nix run .#deploy -- .#k8s-server-1  # one node
```

`heimdall` (cluster ops + `heimdall ai`) is installed on Darwin from its flake input.

## Gaming PC (NixOS)

`gaming-pc` (`modules/hosts/gaming-pc`): MSI board, Ryzen 7 2700X (AIO cooler), 32GB,
GTX 1060 6GB, KDE Plasma 6, Steam (Proton-GE), Lutris (Battle.net: WoW, D4, SC2). The OS
lives on the 240GB SATA SSD (`/dev/sda`, disko, wiped on install); the 1TB NVMe is mounted
at `/games` by label and is **not** in disko, so reinstalling keeps it.

The GTX 1060 (Pascal) needs `nvidiaPackages.legacy_580` with `open = false`: newer driver
branches dropped Pascal and the open kernel modules need Turing or newer.

1. Flash the k8s installer ISO (`./scripts/flash-usb.sh`), boot it on the PC (F11 boot menu)
   on wired ethernet, and note its IP (`ip -4 addr`).
2. `./scripts/install-gaming-pc.sh <installer-ip>`: shows the disks, asks for confirmation,
   clears the SSD (signatures plus the first 1.1GB, so stale ESPs from a previous OS aren't
   reused by disko), installs with nixos-anywhere and generates `hardware-configuration.nix`.
   The NVMe is wiped and formatted (label `games`) only if no `games` filesystem exists yet
   (`GAMES_DISK` overrides the device, default `/dev/nvme0n1`).
3. Commit the generated `hardware-configuration.nix`, log in as `austin`/`changeme` and
   run `passwd`, add a GitHub SSH key and clone this repo to `~/homelab/nix`, then `rebuild`.
4. Point the Steam / Lutris libraries at `/games`.

The install builds on the PC under sustained all-core load. Check cooling first: the CPU
should idle around 35-50°C in the BIOS hardware monitor. Dried thermal paste and a dusty
radiator once made it climb past 85°C at idle and power off mid-install.

## Bootstrap on a New Machine

Each Mac gets its **own** GitHub SSH key (revocable per device) rather than sharing one via
SOPS. SOPS would only move the problem: decrypting needs an age key copied over by hand.

1. Install Nix:
   ```bash
   curl -L https://nixos.org/nix/install | sh
   ```

2. Create this machine's GitHub key and register it (browser login, no key needed yet):
   ```bash
   KEY=<machine-name>   # e.g. austin-mini; becomes machines.<name>.sshKey
   ssh-keygen -t ed25519 -C "$KEY" -f ~/.ssh/$KEY
   nix shell nixpkgs#gh -c sh -c "gh auth login && gh ssh-key add ~/.ssh/$KEY.pub --title $KEY"
   ```

3. Clone both repos:
   ```bash
   mkdir -p ~/homelab
   GIT_SSH_COMMAND="ssh -i ~/.ssh/$KEY" git clone git@github.com:Austin37AF/nix-config.git ~/homelab/nix
   GIT_SSH_COMMAND="ssh -i ~/.ssh/$KEY" git clone git@github.com:Austin37AF/heimdall.git ~/homelab/heimdall
   ```

4. Add the machine to `flake.nix`: an entry in `machines` (`name`, `sshKey = "$KEY"`) and a
   `darwinConfigurations.<name> = mkDarwin machines.<name> [ ];` (add `workModules` for work Macs).
   Commit and push from either machine.

5. Pre-fetch inputs as your user, then switch. The first switch runs as root before the
   SSH-agent passthrough exists, so the private heimdall input must already be in the store:
   ```bash
   ssh-add ~/.ssh/$KEY
   nix flake archive ~/homelab/nix
   sudo nix run nix-darwin -- switch --flake ~/homelab/nix#<name>
   ```

6. Subsequent rebuilds: `rebuild` (and `rebuild-home` on machines with a home variant).

7. Optional, only if this Mac will edit secrets: create its own age key and add it as a
   recipient in `.sops.yaml` from a machine that can already decrypt, then `sops updatekeys`:
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

`~/.ssh/config` is managed by home-manager (`modules/darwin/home.nix`); put ad-hoc hosts in
`~/.ssh/config.local`.

## Manual Steps (New Machine)

- **Raycast**: Set CMD+Space as hotkey (Spotlight is disabled by config)
- **Terminal.app Font** (if using Terminal.app): Settings → Profiles → Font → Change → Select "JetBrainsMono Nerd Font"
- **Devin Desktop font/settings** are merged automatically (see Devin section)

## What's Managed

### Nix Packages (`darwin/default.nix`, `packages.nix`)
- CLI tools (`packages.nix` cli) + GUI apps (`modules/darwin/packages.nix` gui) system-wide
- Fonts (JetBrainsMono Nerd Font)

### Homebrew
- `modules/darwin/homebrew.nix` (all Macs): brews `direnv`; casks `docker-desktop`, `google-chrome`, `raycast`, `slack`, `stats`, `devin-desktop`. `onActivation.upgrade` + `cleanup = "zap"` — anything not declared gets removed on rebuild. Taps pinned via nix-homebrew flake inputs.
- `modules/hosts/work/homebrew.nix` (work only): `gimme-aws-creds`.
- `modules/local-ai/darwin.nix`: casks `lm-studio`, `zed`.

### System Defaults (`darwin/default.nix`)
- Dock: autohide, persistent apps
- Finder: show extensions, path bar, status bar
- Trackpad: right-click enabled
- Keyboard: fast key repeat
- Spotlight: disabled (for Raycast)
- Touch ID: enabled for sudo

### Home Manager (`modules/common/home.nix`, `modules/darwin/home.nix`)
- Git config (user, email, default branch, global ignores for agent files)
- Powerline-go prompt with custom modules (`~/.local/bin/powerline-go-mynix`, `powerline-go-mykube`)
- Zsh completions (sparkctl, valhalla, kubectl)
- SSH config (`~/.ssh/config.local` for ad-hoc hosts)
- Devin CLI + Devin Desktop config (above)

### Dev Shell (`devshell.nix`)
- All CLI tools plus dev-only: go, python3, opentofu, kyverno, kubeconform, kind, act, devbox, helm (with helm-unittest)
- Enter with `dev`, or automatically via direnv under the work dirs

### Shared Packages (`packages.nix`)
- **cli**: awscli2, kubectl, k9s, gh, pre-commit, gcloud (gke-auth-plugin), jq, yq, nixd, devbox, icloudpd, prettier
- **dev**: go, python3+pip, opentofu, powerline-go, helm + helm-unittest, act, kyverno, kubeconform, kind
- **fonts**: JetBrainsMono Nerd Font
- **gui** (`modules/darwin/packages.nix`): vim, mkalias, obsidian, alt-tab, hidden-bar, rectangle, the-unarchiver

### Shared Environment (`env.nix`)
- **vars**: PATH, GOPATH, Docker platform, GKE auth plugin
- **aliases**: k, k_dd, tf, terraform, tf-init-all, google-auth, ll, brt, devin
- **powerlineBash**: Bash prompt config for dev shell
- **showKubeNamespace**: Toggle to always show namespace (default: false)

## Powerline-go Prompt

Custom modules display shell and Kubernetes context:

| Indicator | Meaning |
|-----------|---------|
| ❄️ | Nix dev shell |
| 📦 | Devbox shell |
| 󰡨 (Docker icon) | docker-desktop context |
| GCP-PROD (red) | Production cluster |
| GCP-STAGING (green) | Staging cluster |
| GCP-INFRA (magenta) | Infrastructure cluster |
| brt-prod (red) | BRT EKS prod |
| brtplat-dev (green) | BRT EKS dev |
| brtplat-infr (magenta) | BRT EKS infra |
| mini | minikube |
| context name (grey) | Any other context |

Namespace is shown only when not `default`. To always show namespace, set `showKubeNamespace = true` in `env.nix`.

## Shell Workflow

Terminals open in regular zsh. Under `~/brt-projects` and `~/sparkai-projects`
direnv loads the dev shell automatically; elsewhere enter it manually:

```bash
dev               # Enter nix dev shell → shows ❄️
exit              # Back to base zsh

devbox shell      # Enter devbox (in repos with devbox.json) → shows 📦
exit              # Back to base zsh
```

## Garbage Collection

Runs weekly, deletes generations older than 14 days. Manual run:
```bash
nix-collect-garbage -d
```

## Related Repos

- [heimdall](https://github.com/Austin37AF/heimdall) - CLI tool for cluster management
- [k8s-gitops](https://github.com/Austin37AF/k8s-gitops) - GitOps repository for cluster apps
