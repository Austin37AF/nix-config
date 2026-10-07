# Nix Darwin Configuration

Declarative macOS system configuration using nix-darwin, nix-homebrew, and Home Manager.

## Structure

```
~/homelab/nix/
├── flake.nix              # Entry point
├── modules/
│   ├── darwin.nix         # System settings, defaults, fonts
│   ├── homebrew.nix       # Homebrew brews and casks
│   ├── zsh.nix            # Shell configuration
│   ├── home.nix           # Home Manager (git, powerline-go, Windsurf settings)
│   ├── local-ai/          # LM Studio + Zed (Qwen3.6-27B, PR review skill) + nvtop; not on k8s nodes
│   ├── devshell.nix       # Dev shell for projects without Devbox
│   ├── packages.nix       # Shared package lists (cli, dev, fonts, gui)
│   └── env.nix            # Shared env vars, aliases, powerline config
```

## Quick Commands

```bash
# Rebuild system configuration (rebuild-home for personal mode)
rebuild

# Enter dev shell manually (go, python, opentofu, jq, yq)
dev

# Update flake inputs
nix flake update

# Exit current shell
exit
```

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
- **Company apps**: Chrome and Slack are pre-installed by MDM — uncomment in `homebrew.nix` if needed
- **Terminal.app Font** (if using Terminal.app): Settings → Profiles → Font → Change → Select "JetBrainsMono Nerd Font"
- **Windsurf font is auto-configured** via `home.nix`

## What's Managed

### Nix Packages (`darwin.nix`)
- CLI tools + GUI apps installed system-wide
- Fonts (JetBrainsMono Nerd Font)

### Homebrew (`homebrew.nix`)
- **Brews**: awscli, direnv, gh, gimme-aws-creds, k9s, pre-commit, mas
- **Casks**: docker-desktop, gcloud-cli, google-drive, raycast

### System Defaults (`darwin.nix`)
- Dock: autohide, persistent apps
- Finder: show extensions, path bar, status bar
- Trackpad: right-click enabled
- Keyboard: fast key repeat
- Spotlight: disabled (for Raycast)
- Touch ID: enabled for sudo

### Home Manager (`home.nix`)
- Git config (user, email, default branch)
- Powerline-go prompt with custom modules (mynix, mykube)
- Zsh completions (sparkctl, valhalla, kubectl)
- Windsurf settings (font, terminal profile, nix language server)
- Custom scripts in `~/.local/bin`

### Dev Shell (`devshell.nix`)
- Includes all CLI tools plus: go, python3, opentofu, powerline-go, act
- Shows ❄️ indicator in prompt
- Enter with `dev` alias

### Shared Packages (`packages.nix`)
- **cli**: awscli, kubectl, helm, k9s, gh, pre-commit, gcloud (with gke-auth-plugin), jq, yq, nixd
- **dev**: go, python3, opentofu, powerline-go, act
- **fonts**: JetBrainsMono Nerd Font (for powerline-go icons)
- **gui**: vim, mkalias, obsidian, alt-tab, hidden-bar, rectangle, stats, the-unarchiver

### Shared Environment (`env.nix`)
- **vars**: PATH, GOPATH, Docker platform, Zscaler certs, GKE auth plugin
- **aliases**: k, k_dd, tf, terraform, tf-init-all, google-auth, ll
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

Namespace is shown only when not `default`. To always show namespace, set `showKubeNamespace = true` in `env.nix`.

## Shell Workflow

Windsurf terminals open in regular zsh. Enter dev environments as needed:

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

## Company-Managed Apps (Not in Config)

- Google Chrome
- Slack

## Related Repos

- [heimdall](https://github.com/Austin37AF/heimdall) - CLI tool for cluster management
- [k8s-gitops](https://github.com/Austin37AF/k8s-gitops) - GitOps repository for cluster apps
