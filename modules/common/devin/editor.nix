# Devin Desktop (formerly Windsurf) editor settings
#
# The editor writes settings.json itself, so it must stay a regular file:
# the activation script merges the managed keys in (managed keys win,
# everything else is kept).
{ lib, pkgs, ... }:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  settingsPath =
    if isDarwin
    then "$HOME/Library/Application Support/Devin/User/settings.json"
    else "$HOME/.config/Devin/User/settings.json";

  terminalSettings =
    if isDarwin then {
      "terminal.integrated.defaultProfile.osx" = "zsh";
      "terminal.integrated.profiles.osx" = {
        bash = { path = "/bin/bash"; args = ["-l"]; };
        zsh = { path = "/bin/zsh"; args = ["-l"]; };
      };
    } else {
      "terminal.integrated.defaultProfile.linux" = "zsh";
    };

  editorSettings = {
    "security.workspace.trust.untrustedFiles" = "open";
    "files.autoSave" = "onFocusChange";
    "terminal.integrated.fontFamily" = "JetBrainsMono Nerd Font";
    # Nix language server
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = "nixd";
    # Prevent Windsurf from trying to modify settings
    "window.restoreWindows" = "all";
    "workbench.startupEditor" = "none";
    "telemetry.telemetryLevel" = "off";
  } // terminalSettings;

  editorSettingsMerge = pkgs.writeShellScript "devin-editor-settings" ''
    set -euo pipefail
    cfg="${settingsPath}"
    jq=${pkgs.jq}/bin/jq
    mkdir -p "$(dirname "$cfg")"
    # Replace an old home-manager store symlink with a regular file
    if [ -L "$cfg" ]; then rm -f "$cfg"; fi
    existing='{}'
    if [ -s "$cfg" ]; then existing=$(cat "$cfg"); fi
    if ! printf '%s' "$existing" | "$jq" -e . >/dev/null 2>&1; then
      echo "warning: $cfg is not plain JSON; leaving it unchanged" >&2
      exit 0
    fi
    new=$(printf '%s' "$existing" | "$jq" --argjson m ${lib.escapeShellArg (builtins.toJSON editorSettings)} '. * $m')
    if [ -f "$cfg" ] && printf '%s\n' "$new" | cmp -s - "$cfg"; then exit 0; fi
    tmp=$(mktemp "$cfg.XXXXXX")
    printf '%s\n' "$new" > "$tmp"
    mv -f "$tmp" "$cfg"
  '';
in
{
  home.activation.devinEditorSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${editorSettingsMerge}
  '';
}
