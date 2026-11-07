# WSL-specific Home Manager settings
{ lib, pkgs, ... }:

let
  windowsHome = "/mnt/c/Users/austi";

  # Devin Desktop on the Windows side: terminals open in NixOS (zsh), windows restore (incl. WSL remotes)
  editorSettings = {
    "terminal.integrated.defaultProfile.windows" = "NixOS (WSL)";
    "terminal.integrated.profiles.windows" = {
      "NixOS (WSL)" = {
        path = "C:\\Windows\\System32\\wsl.exe";
        args = [ "-d" "NixOS" "--cd" "~" ];
        icon = "terminal-linux";
      };
    };
    "terminal.integrated.defaultProfile.linux" = "zsh";
    "terminal.integrated.fontFamily" = "JetBrainsMono Nerd Font";
    "window.restoreWindows" = "all";
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = "nixd";
  };

  # Devin Desktop writes settings.json itself: merge the managed keys in (managed keys win)
  editorSettingsMerge = pkgs.writeShellScript "devin-editor-settings-windows" ''
    set -euo pipefail
    cfg="${windowsHome}/AppData/Roaming/Devin/User/settings.json"
    jq=${pkgs.jq}/bin/jq
    [ -d "$(dirname "$cfg")" ] || exit 0
    existing='{}'
    if [ -s "$cfg" ]; then existing=$(cat "$cfg"); fi
    if ! printf '%s' "$existing" | "$jq" -e . >/dev/null 2>&1; then
      echo "warning: $cfg is not plain JSON; leaving it unchanged" >&2
      exit 0
    fi
    new=$(printf '%s' "$existing" | "$jq" --argjson m ${lib.escapeShellArg (builtins.toJSON editorSettings)} '. * $m')
    if [ -f "$cfg" ] && printf '%s\n' "$new" | cmp -s - "$cfg"; then exit 0; fi
    printf '%s\n' "$new" > "$cfg"
  '';

  # JetBrainsMono Nerd Font for Windows apps (powerline glyphs): per-user install, no admin needed
  windowsNerdFont = pkgs.writeShellScript "windows-nerd-font" ''
    set -uo pipefail
    dir="${windowsHome}/AppData/Local/Microsoft/Windows/Fonts"
    winDir='C:\Users\austi\AppData\Local\Microsoft\Windows\Fonts'
    key='HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    reg=/mnt/c/Windows/System32/reg.exe
    [ -d "${windowsHome}" ] || exit 0
    mkdir -p "$dir"
    registered=$("$reg" query "$key" 2>/dev/null | tr -d '\r' || true)
    find ${pkgs.nerd-fonts.jetbrains-mono}/share/fonts -name 'JetBrainsMonoNerdFont-*.ttf' | while read -r f; do
      name=$(basename "$f")
      style=''${name#JetBrainsMonoNerdFont-}
      style=''${style%.ttf}
      if ! cmp -s "$f" "$dir/$name"; then
        install -m 644 "$f" "$dir/$name" || echo "warning: could not copy $name (font in use?)" >&2
      fi
      value="JetBrainsMono Nerd Font $style (TrueType)"
      if ! printf '%s\n' "$registered" | grep -qF "$value"; then
        "$reg" add "$key" /v "$value" /t REG_SZ /d "$winDir\\$name" /f </dev/null >/dev/null 2>&1 \
          || echo "warning: could not register $name" >&2
      fi
    done
  '';

  # Git for Windows: when Devin Desktop opens the workspace over
  # \\wsl.localhost (no WSL remote server), its SCM extension probes fixed
  # git.exe paths on the Windows side. Installs via winget on first rebuild.
  # The Git.Git installer UAC-elevates, so this is guarded by the probe paths
  # and timeout-wrapped — it can't block a rebuild, only warn.
  gitForWindows = pkgs.writeShellScript "git-for-windows" ''
    set -uo pipefail
    [ -f "/mnt/c/Program Files/Git/cmd/git.exe" ] && exit 0
    [ -f "/mnt/c/Users/austi/AppData/Local/Programs/Git/cmd/git.exe" ] && exit 0
    /mnt/c/Windows/System32/where.exe /Q git >/dev/null 2>&1 && exit 0

    winget=/mnt/c/Users/austi/AppData/Local/Microsoft/WindowsApps/winget.exe
    [ -f "$winget" ] || { echo "warning: winget not found; skipping Git for Windows" >&2; exit 0; }
    ${pkgs.coreutils}/bin/timeout 180 "$winget" install -e --id Git.Git \
      --accept-source-agreements --accept-package-agreements --disable-interactivity \
      || echo "warning: Git for Windows install failed or UAC was declined" >&2
  '';
in
{
  # direnv auto-loads the dev shell, like modules/hosts/work/direnv.nix on the
  # Mac. nix-direnv backs `use flake` and caches the shell (second entry ~0.2s).
  # The whitelist uses `exact` (not `prefix`): a prefix whitelist would
  # auto-trust any .envrc committed under ~/repos.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = false; # common/zsh.nix already runs `direnv hook zsh`
  };

  home.file = {
    ".config/direnv/direnv.toml".text = ''
      [global]
      hide_env_diff = true

      [whitelist]
      exact = ["/home/nixos/repos/.envrc", "/home/nixos/repos/nix-config/.envrc", "/home/nixos/homelab/nix/.envrc"]
    '';

    # Every repo under ~/repos gets the nix-config dev shell; a repo's own
    # .envrc (e.g. this repo's) wins as the nearer file.
    "repos/.envrc".text = ''
      use flake /home/nixos/homelab/nix
      watch_file /home/nixos/homelab/nix/flake.lock /home/nixos/homelab/nix/modules/devshell.nix /home/nixos/homelab/nix/modules/common/packages.nix /home/nixos/homelab/nix/modules/common/env.nix
    '';
  };

  home.activation.devinEditorSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${editorSettingsMerge}
  '';

  home.activation.windowsNerdFont = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${windowsNerdFont}
  '';

  home.activation.gitForWindows = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${gitForWindows}
  '';
}
