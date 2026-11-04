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
in
{
  home.activation.devinEditorSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${editorSettingsMerge}
  '';

  home.activation.windowsNerdFont = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${windowsNerdFont}
  '';
}
