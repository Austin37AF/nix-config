# Nix Darwin Configuration

Declarative macOS system configuration using nix-darwin, nix-homebrew, and Home Manager.

## Structure

```
~/nix/
├── flake.nix              # Entry point
├── modules/
│   ├── darwin.nix         # System settings, defaults, fonts
│   ├── homebrew.nix       # Homebrew brews and casks
│   ├── zsh.nix            # Shell configuration
│   ├── home.nix           # Home Manager (git, powerline-go, Windsurf settings)
│   ├── devshell.nix       # Dev shell for projects without Devbox
│   ├── packages.nix       # Shared package lists (cli, dev, fonts, gui)
│   └── env.nix            # Shared env vars, aliases, powerline config
```

## Quick Commands

```bash
# Rebuild system configuration
rebuild

# Enter dev shell manually (go, python, opentofu, jq, yq)
dev

# Update flake inputs
nix flake update

# Exit nix shell to base zsh (for devbox)
exit
```

## Bootstrap on a New Machine

1. Install Nix:
   ```bash
   curl -L https://nixos.org/nix/install | sh
   ```

2. Clone this repo:
   ```bash
   git clone git@github.com:Austin37AF/nix-config.git ~/nix
   ```

3. Build and switch:
   ```bash
   nix run nix-darwin -- switch --flake ~/nix#austin-m5-pro
   ```

4. Subsequent rebuilds:
   ```bash
   rebuild
   ```

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
- Includes all CLI tools plus: go, python3, opentofu, powerline-go
- Shows ❄️ indicator in prompt
- **Windsurf auto-enters this shell** on terminal open
- `exit` returns to base zsh for devbox

### Shared Packages (`packages.nix`)
- **cli**: awscli, kubectl, helm, k9s, gh, pre-commit, gcloud (with gke-auth-plugin), jq, yq, nixd
- **dev**: go, python3, opentofu, powerline-go
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

## Devbox Workflow

Windsurf terminals auto-enter the nix dev shell. For repos with devbox:

```bash
exit              # Exit nix shell → base zsh
devbox shell      # Enter devbox → shows 📦
exit              # Back to base zsh
exit              # Close terminal
```

## Garbage Collection

Runs weekly, deletes generations older than 14 days. Manual run:
```bash
nix-collect-garbage -d
```

## Company-Managed Apps (Not in Config)

- Google Chrome
- Slack
