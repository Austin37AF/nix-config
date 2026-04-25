# Nix Darwin Configuration

Declarative macOS system configuration using nix-darwin, nix-homebrew, and Home Manager.

## Structure

```
~/nix/
├── flake.nix              # Entry point
├── modules/
│   ├── darwin.nix         # System settings, defaults
│   ├── homebrew.nix       # Homebrew brews and casks
│   ├── zsh.nix            # Shell configuration
│   ├── home.nix           # Home Manager (git, powerline-go)
│   ├── devshell.nix       # Dev shell for projects without Devbox
│   ├── packages.nix       # Shared package lists (cli, dev, gui)
│   └── env.nix            # Shared env vars, aliases, powerline config
```

## Quick Commands

```bash
# Rebuild system configuration
rebuild

# Enter dev shell (go, python, opentofu, jq, yq)
dev

# Update flake inputs
nix flake update
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

## What's Managed

### Nix Packages (`darwin.nix`)
- vim, obsidian, alt-tab, hidden-bar, rectangle, stats, the-unarchiver

### Homebrew Brews (`homebrew.nix`)
- awscli, direnv, gh, gimme-aws-creds, k9s, pre-commit, mas

### Homebrew Casks (`homebrew.nix`)
- docker-desktop, gcloud-cli, google-drive, raycast

### System Defaults (`darwin.nix`)
- Dock: autohide, persistent apps
- Finder: show extensions, path bar, status bar
- Trackpad: three-finger drag, right-click
- Keyboard: fast key repeat
- Spotlight: disabled (for Raycast)
- Touch ID: enabled for sudo

### Home Manager (`home.nix`)
- Git config (user, email, default branch)
- Powerline-go prompt
- Zsh completions (sparkctl, valhalla, kubectl)

### Dev Shell (`devshell.nix`)
- Includes all CLI tools plus: go, python3, opentofu
- Shows `[dev]` tag and k8s context in prompt
- Invoke with `dev` alias

### Shared Packages (`packages.nix`)
- **cli**: awscli, kubectl, helm, k9s, gh, pre-commit, gcloud (with gke-auth-plugin), jq, yq
- **dev**: go, python3, opentofu, powerline-go
- **gui**: vim, obsidian, alt-tab, hidden-bar, rectangle, stats, the-unarchiver

### Shared Environment (`env.nix`)
- **vars**: PATH, GOPATH, Docker platform, Zscaler certs, GKE auth plugin
- **aliases**: k, k_dd, tf, terraform, tf-init-all, google-auth, ll
- **powerlineBash**: Dev shell prompt config with k8s context

## Garbage Collection

Runs weekly, deletes generations older than 14 days. Manual run:
```bash
nix-collect-garbage -d
```

## Company-Managed Apps (Not in Config)

- Google Chrome
- Slack
