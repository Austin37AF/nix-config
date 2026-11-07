# Nix Configuration

Declarative configuration for macOS (nix-darwin, nix-homebrew, Home Manager),
NixOS hosts (gaming PC, NixOS-WSL), and a k3s cluster on Mac minis.

## Structure

Every machine is a standalone flake in `hosts/<name>/` with its **own `flake.lock`**, so
updating or breaking one machine never touches another. Shared modules live in `shared/`
and a machine only gets one if it lists it in its imports (or in its `flake.nix`).

```
~/homelab/nix/
├── flake.nix                    # Root flake: dev shell + installer ISO only (no machines)
├── hosts/
│   ├── austin-m5-pro/           # Work MacBook (nix-darwin): austin-m5-pro + austin-m5-pro-home
│   │   ├── flake.nix            # darwinConfigurations; own flake.lock
│   │   ├── default.nix          # System settings, defaults, activation
│   │   ├── packages.nix         # macOS GUI apps (vim, obsidian, rectangle, ...)
│   │   ├── homebrew.nix         # Homebrew brews and casks
│   │   ├── home.nix             # Darwin HM: ssh config, Devin Desktop editor settings merge
│   │   ├── cert-pem.nix         # eMudhra response: prunes distrusted roots from /etc/ssl/cert.pem
│   │   ├── zsh.nix              # zsh + rebuild/rebuild-home aliases
│   │   ├── local-ai/            # LM Studio + Zed (local LLM) config
│   │   └── work/                # Work-only (austin-m5-pro, not -home): Zscaler, work brews, direnv, Devin addendum
│   ├── gaming-pc/               # NixOS gaming PC (Plasma 6, NVIDIA 580 legacy, Steam)
│   │   ├── flake.nix            # own flake.lock
│   │   ├── default.nix, home.nix, hardware-configuration.nix
│   │   ├── wow-forever/         # WoW Forever via battlenet-umu + declarative addons
│   │   └── install-hook.sh      # install-host hook: formats the games disk once
│   ├── wsl/                     # NixOS-WSL on the Windows PC (own flake.lock)
│   └── k8s/                     # k3s cluster nodes, deploy-rs, sops secrets (own flake.lock)
├── shared/                      # Opt-in modules, imported by hosts that want them
│   ├── home.nix                 # Home Manager: git, powerline-go, shell config
│   ├── packages.nix             # Package lists: cli, dev, fonts
│   ├── env.nix                  # Env vars, aliases, powerline config
│   ├── zsh.nix                  # zsh + direnv hook (NixOS)
│   ├── devin/                   # Devin CLI: AGENTS.md, mcp_config.json, config.json merge, permissions
│   ├── disko-single-disk.nix    # GPT + ESP + ext4 root disk layout
│   ├── ssh-keys.nix             # Admin SSH public keys
│   └── devshell.nix             # `nix develop` dev shell (also loaded by direnv)
├── installer/                   # Installer ISO for all NixOS hosts + `install-host` menu
├── scripts/                     # update.sh, flash-usb.sh, install-node.sh, install-gaming-pc.sh
├── devbox.json                  # Cluster-management shell (sops, age, kubectl, helm, k9s)
└── .github/workflows/           # flake-check (one job per changed host), build-iso
```

### Adding a machine

1. `mkdir hosts/<name>` and add a `flake.nix` (copy the closest host's) plus its modules.
2. Import only the shared modules it should have, e.g. `../../shared/zsh.nix`. Leave a line
   out and the machine doesn't get it.
3. `nix flake lock ./hosts/<name>`, `git add hosts/<name>` (flakes only see Git-tracked files).
4. In `.github/workflows/flake-check.yaml`, add it to the `flakes` list and give it a
   `hosts/<name>/**` paths filter in the `changes` job.
5. NixOS with a disko layout: it shows up in the installer's `install-host` menu automatically.

### CI

`flake-check` checks only the flakes whose files changed: `hosts/<name>/**` checks that host,
`flake.nix`/`flake.lock`/`installer/**` the root flake, and `shared/**` or the workflow itself
checks every host. Docs-only changes skip it. A manual run (`workflow_dispatch`) checks all.
The Mac job evaluates both darwin systems (aarch64-darwin can't be built on the Linux runner).

### Updating inputs

`./scripts/update.sh <host>` updates one machine's lock (`./scripts/update.sh all` for
everything, `./scripts/update.sh k8s -- nixpkgs` for one input). Rebuild that machine after.

Two configs share the work Mac: `austin-m5-pro` (work, adds `./work`) and
`austin-m5-pro-home` (personal, no work modules). Rebuild with `rebuild` /
`rebuild-home` (needs sudo).

## Quick Commands

```bash
rebuild                    # darwin-rebuild switch (work config); primes the SSH agent first so root can fetch the private heimdall input
rebuild-home               # switch to the personal config
dev                        # nix dev shell manually (outside direnv dirs)
./scripts/update.sh austin-m5-pro  # update this Mac's inputs (each host has its own lock)
```

## Certificates / Zscaler (work)

- `security.pki.certificateFiles` appends `zscaler-root.crt` to the nixpkgs
  cacert bundle at `/etc/ssl/certs/ca-certificates.crt`; the same file is
  linked at `~/certs/bundle.crt` for tools that need a stable path
  (`http.sslCAInfo`, gcloud `custom_ca_certs_file`).
- `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS` and
  `NIX_SSL_CERT_FILE` all point at it (`hosts/austin-m5-pro/work/zscaler.nix`,
  `shared/env.nix`).
- `cert-pem.nix` (eMudhra compromise): every rebuild, an activation step
  removes distrusted roots (emSign ECC Root CA - G3, AAA Certificate Services)
  from `/etc/ssl/cert.pem`, keeping a backup at `/etc/ssl/cert.pem.orig`.
  It's a no-op once Apple ships a clean file.

## Devin (CLI + Desktop)

- `~/.config/devin/AGENTS.md`: global rules — base set (`shared/devin`)
  plus a work addendum (Zscaler, kubectl/helm/Atlantis guardrails,
  `hosts/austin-m5-pro/work/devin`).
- `mcp_config.json`: declarative user-scope MCP servers (Atlassian).
- `config.json`: **merged** on activation, not symlinked — Devin mutates it
  (approvals, keymap, hooks). Managed keys win, `permissions.allow/ask/deny`
  are unioned with existing, JSONC/non-JSON files are left alone. Managed
  settings include the Fusion default model and the permission lists. Note:
  removing an entry from the Nix lists does not remove it from the file.
- Per-repo `AGENTS.local.md` notes and `~/.config/devin/skills/*` are
  **out-of-store symlinks** into `hosts/austin-m5-pro/work/devin/` — edits apply
  without a rebuild. `AGENTS.local.md` is ignored globally via
  `programs.git.ignores`.
- Skills:

  | Skill | What it does |
  |---|---|
  | `chart-check` | Lint/render Helm charts like CI (helm template, unittest, kubeconform) |
  | `kyverno-test` | Test Kyverno policies on a throwaway kind cluster, then clean up |
  | `go-bump-release` | Bump a Go repo's version, PR, release, verify published binaries |
  | `ci-local` | Run a repo's GitHub Actions jobs locally with `act` |

- Permissions (in `shared/devin/default.nix`):
  - allow: read-only git, `nix eval/build/flake show|metadata|check`, `darwin-rebuild build`, `gh pr view/diff/checks`, terraform/tofu `fmt`/`validate`, `helm template/lint`, `pre-commit run`, `aws sts get-caller-identity`
  - ask: terraform/tofu `apply`/`destroy`, mutating kubectl, `helm install/upgrade/uninstall`
  - deny: `sudo`, `darwin-rebuild switch/activate`, `git push --force*`
  - Matching is on the start of the command only, so the cluster-safety rules in AGENTS.md are the real guard.
- `attribution = false`: no Devin trailer on commits/PRs.
- Devin Desktop's `settings.json` (formerly Windsurf) is also merged on
  activation (managed keys win; stays a regular file).
- To add a repo to the personal notes: drop a markdown file in
  `hosts/austin-m5-pro/work/devin/repos/` and add one line to `outOfStoreLinks` in
  `hosts/austin-m5-pro/work/devin/default.nix`.

## Work dev shell via direnv

- `.envrc` in `~/brt-projects` and `~/sparkai-projects` (Mac) and `~/repos`
  (WSL, gaming PC) runs `use flake ~/homelab/nix` (the root flake's dev shell); nix-direnv caches the shell (second
  entry ~0.2s). `direnv.toml` whitelists those exact paths only — a repo's
  own `.envrc` needs a one-time `direnv allow`.
- This repo also commits a `.envrc` (`use flake`), whitelisted on both hosts
  (`~/homelab/nix`, `~/repos/nix-config`).
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

## Local AI (`hosts/austin-m5-pro/local-ai`)

- LM Studio + Zed (Homebrew casks); Zed is configured against LM Studio's local server (Qwen3.6-27B) with a `pr-review` skill in `~/.agents/skills`.
- One-time model download (after launching LM Studio once): `lms get qwen/qwen3.6-27b --mlx --select` and pick the 6-bit quant.
- Day to day: `heimdall ai up | down | status`.

## Homelab Kubernetes Cluster (`hosts/k8s`)

NixOS k3s cluster on Mac minis; full guide in [`hosts/k8s/README.md`](hosts/k8s/README.md).

```bash
devbox shell                        # repo root: sops, age, kubectl, helm, k9s
sops hosts/k8s/secrets/k8s.yaml     # edit secrets
cd hosts/k8s
nix run .#deploy                    # deploy all nodes (or: heimdall cluster update)
nix run .#deploy -- .#k8s-server-1  # one node
```

`heimdall` (cluster ops + `heimdall ai`) is installed on the Mac, gaming-pc and WSL from each
host's heimdall flake input. `heimdall cluster update` deploys from `~/homelab/nix/hosts/k8s`.

## Gaming PC (NixOS)

`gaming-pc` (`hosts/gaming-pc`): MSI board, Ryzen 7 2700X (AIO cooler), 32GB,
GTX 1060 6GB, KDE Plasma 6, Steam (Proton-GE), Lutris, WoW Forever (Battle.net via
battlenet-umu, `hosts/gaming-pc/wow-forever`), Discord, Chrome, Bambu Studio. The OS
lives on the 240GB SATA SSD (`/dev/sda`, disko, wiped on install); the 1TB NVMe is mounted
at `/games` by label and is **not** in disko, so reinstalling keeps it.

The GTX 1060 (Pascal) needs `nvidiaPackages.legacy_580` with `open = false`: newer driver
branches dropped Pascal and the open kernel modules need Turing or newer.

1. Flash the installer ISO (`./scripts/flash-usb.sh`), boot it on the PC (F11 boot menu)
   on wired ethernet, and note its IP (`ip -4 addr`).
2. Either `ssh -A root@<installer-ip>` and run `install-host` (pick `gaming-pc`; it runs
   `hosts/gaming-pc/install-hook.sh` for the games disk), or from the Mac
   `./scripts/install-gaming-pc.sh <installer-ip>`: shows the disks, asks for confirmation,
   clears the SSD (signatures plus the first 1.1GB, so stale ESPs from a previous OS aren't
   reused by disko), installs with nixos-anywhere and generates `hardware-configuration.nix`.
   The NVMe is wiped and formatted (label `games`) only if no `games` filesystem exists yet
   (`GAMES_DISK` overrides the device, default `/dev/nvme0n1`).
3. Commit the generated `hardware-configuration.nix`, log in as `austin`/`changeme` and
   run `passwd`. Create the PC's GitHub key (`ssh-keygen -t ed25519 -C gaming-pc -f ~/.ssh/gaming-pc`,
   then `gh ssh-key add` it), clone this repo to `~/homelab/nix` and run the first switch from the
   Mac with agent forwarding: `ssh -A -t austin@<ip> 'nix flake archive ~/homelab/nix/hosts/gaming-pc && sudo nixos-rebuild switch --flake ~/homelab/nix/hosts/gaming-pc#gaming-pc'`.
   After that, `rebuild` on the PC builds as `austin` (Home Manager points GitHub at
   `~/.ssh/gaming-pc`) and activates with sudo.
4. Point the Steam / Lutris libraries at `/games`.

Apps are in `hosts/gaming-pc/home.nix` (`home.packages`). After a `rebuild` that adds an app,
a Plasma session that was already running may not show it in the launcher/search, or may show
it without an icon, until Plasma reloads: `systemctl --user restart plasma-plasmashell` (or log
out and back in). Bambu Studio is partly unfree, so cache.nixos.org has no prebuilt copy: it
compiles from source after each nixpkgs update, which makes that rebuild long.

The install builds on the PC under sustained all-core load. Check cooling first: the CPU
should idle around 35-50°C in the BIOS hardware monitor. Dried thermal paste and a dusty
radiator once made it climb past 85°C at idle and power off mid-install.

## WSL (NixOS-WSL)

`wsl` (`hosts/wsl`): NixOS-WSL on the Windows PC, default user `nixos`. Shared CLI
packages, zsh with the powerline prompt, Home Manager (`shared/home.nix`: git, prompt
scripts) and heimdall. The repo lives at `~/repos/nix-config`; a tmpfiles symlink provides
`~/homelab/nix` for the shared aliases. zsh is the default shell for all users.

- `hosts/wsl/home.nix` merges Devin Desktop settings into the **Windows**
  `%APPDATA%\Devin\User\settings.json` (via `/mnt/c`): the default integrated terminal is
  `wsl.exe -d NixOS` and windows restore (so a WSL remote window reopens). Managed keys
  win, the rest of the file is kept.
- The same module installs JetBrainsMono Nerd Font on Windows per user (no admin): copies
  the TTFs to `%LOCALAPPDATA%\Microsoft\Windows\Fonts` and registers them under
  `HKCU\...\CurrentVersion\Fonts` with `reg.exe`. It's also the Devin Desktop terminal font.

- `rebuild` runs `nixos-rebuild switch --flake ~/homelab/nix/hosts/wsl#wsl --sudo`: it builds as
  `nixos` (so the private heimdall input is fetched with the user's SSH key) and only
  activates as root.
- First switch from a stock NixOS-WSL install (flakes not enabled yet):
  ```bash
  NIX_CONFIG="experimental-features = nix-command flakes" \
    nixos-rebuild switch --flake ~/repos/nix-config/hosts/wsl#wsl --sudo
  ```
  Then `wsl --shutdown` from Windows to apply the hostname and login shell.

## Bootstrap on a New Machine

Each Mac gets its **own** GitHub SSH key (revocable per device) rather than sharing one via
SOPS. SOPS would only move the problem: decrypting needs an age key copied over by hand.

1. Install Nix:
   ```bash
   curl -L https://nixos.org/nix/install | sh
   ```

2. Create this machine's GitHub key and register it (browser login, no key needed yet):
   ```bash
   KEY=<machine-name>   # e.g. austin-mini; becomes machine.sshKey in hosts/<name>/flake.nix
   ssh-keygen -t ed25519 -C "$KEY" -f ~/.ssh/$KEY
   nix shell nixpkgs#gh -c sh -c "gh auth login && gh ssh-key add ~/.ssh/$KEY.pub --title $KEY"
   ```

3. Clone both repos:
   ```bash
   mkdir -p ~/homelab
   GIT_SSH_COMMAND="ssh -i ~/.ssh/$KEY" git clone git@github.com:Austin37AF/nix-config.git ~/homelab/nix
   GIT_SSH_COMMAND="ssh -i ~/.ssh/$KEY" git clone git@github.com:Austin37AF/heimdall.git ~/homelab/heimdall
   ```

4. Add the machine as `hosts/<name>/` (copy `hosts/austin-m5-pro`, set `machine` in its
   `flake.nix` to `name`/`sshKey = "$KEY"`, drop `./work` unless it's a work Mac), then
   `nix flake lock ./hosts/<name>`. Commit and push from either machine.

5. Pre-fetch inputs as your user, then switch. The first switch runs as root before the
   SSH-agent passthrough exists, so the private heimdall input must already be in the store:
   ```bash
   ssh-add ~/.ssh/$KEY
   nix flake archive ~/homelab/nix/hosts/<name>
   sudo nix run nix-darwin -- switch --flake ~/homelab/nix/hosts/<name>#<name>
   ```

6. Subsequent rebuilds: `rebuild` (and `rebuild-home` on machines with a home variant).

7. Optional, only if this Mac will edit secrets: create its own age key and add it as a
   recipient in `.sops.yaml` from a machine that can already decrypt, then `sops updatekeys`:
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

`~/.ssh/config` is managed by home-manager (`hosts/austin-m5-pro/home.nix`); put ad-hoc hosts in
`~/.ssh/config.local`.

## Manual Steps (New Machine)

- **Raycast**: Set CMD+Space as hotkey (Spotlight is disabled by config)
- **Terminal.app Font** (if using Terminal.app): Settings → Profiles → Font → Change → Select "JetBrainsMono Nerd Font"
- **Devin Desktop font/settings** are merged automatically (see Devin section)

## What's Managed

### Nix Packages (`hosts/austin-m5-pro/default.nix`, `shared/packages.nix`)
- CLI tools (`packages.nix` cli) + GUI apps (`hosts/austin-m5-pro/packages.nix` gui) system-wide
- Fonts (JetBrainsMono Nerd Font)

### Homebrew
- `hosts/austin-m5-pro/homebrew.nix` (both configs): brews `direnv`; casks `docker-desktop`, `google-chrome`, `raycast`, `slack`, `stats`, `devin-desktop`. `onActivation.upgrade` + `cleanup = "zap"` — anything not declared gets removed on rebuild. Taps pinned via nix-homebrew flake inputs.
- `hosts/austin-m5-pro/work/homebrew.nix` (work only): `gimme-aws-creds`.
- `hosts/austin-m5-pro/local-ai/darwin.nix`: casks `lm-studio`, `zed`.

### System Defaults (`hosts/austin-m5-pro/default.nix`)
- Dock: autohide, persistent apps
- Finder: show extensions, path bar, status bar
- Trackpad: right-click enabled
- Keyboard: fast key repeat
- Spotlight: disabled (for Raycast)
- Touch ID: enabled for sudo

### Home Manager (`shared/home.nix`, `hosts/austin-m5-pro/home.nix`)
- Git config (user, email, default branch, global ignores for agent files)
- Powerline-go prompt with custom modules (`~/.local/bin/powerline-go-mynix`, `powerline-go-mykube`)
- Zsh completions (sparkctl, valhalla, kubectl)
- SSH config (`~/.ssh/config.local` for ad-hoc hosts)
- Devin CLI + Devin Desktop config (above)

### Dev Shell (`shared/devshell.nix`)
- All CLI tools plus dev-only: go, python3, opentofu, kyverno, kubeconform, kind, act, devbox, helm (with helm-unittest)
- Enter with `dev`, or automatically via direnv under the work dirs

### Shared Packages (`shared/packages.nix`)
- **cli**: awscli2, kubectl, k9s, gh, pre-commit, gcloud (gke-auth-plugin), jq, yq, nixd, devbox, icloudpd, prettier
- **dev**: go, python3+pip, opentofu, powerline-go, helm + helm-unittest, act, kyverno, kubeconform, kind
- **fonts**: JetBrainsMono Nerd Font
- **gui** (`hosts/austin-m5-pro/packages.nix`): vim, mkalias, obsidian, alt-tab, hidden-bar, rectangle, the-unarchiver

### Shared Environment (`shared/env.nix`)
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

Namespace is shown only when not `default`. To always show namespace, set `showKubeNamespace = true` in `shared/env.nix`.

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

Runs weekly on every host, deletes generations older than 14 days. Manual run:
```bash
nix-collect-garbage -d
```

## Related Repos

- [heimdall](https://github.com/Austin37AF/heimdall) - CLI tool for cluster management
- [k8s-gitops](https://github.com/Austin37AF/k8s-gitops) - GitOps repository for cluster apps
