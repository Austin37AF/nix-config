# Darwin-specific home-manager settings
{ machine, lib, pkgs, ... }:

let
  # Devin Desktop (formerly Windsurf) editor settings
  editorSettings = {
    "security.workspace.trust.untrustedFiles" = "open";
    "files.autoSave" = "onFocusChange";
    "terminal.integrated.fontFamily" = "JetBrainsMono Nerd Font";
    "terminal.integrated.defaultProfile.osx" = "zsh";
    "terminal.integrated.profiles.osx" = {
      bash = { path = "/bin/bash"; args = ["-l"]; };
      zsh = { path = "/bin/zsh"; args = ["-l"]; };
    };
    # Nix language server
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = "nixd";
    # Prevent Windsurf from trying to modify settings
    "window.restoreWindows" = "all";
    "workbench.startupEditor" = "none";
    "telemetry.telemetryLevel" = "off";
  };

  # The editor writes settings.json itself, so it must stay a regular file:
  # merge the managed keys in (managed keys win, everything else is kept).
  editorSettingsMerge = pkgs.writeShellScript "devin-editor-settings" ''
    set -euo pipefail
    cfg="$HOME/Library/Application Support/Devin/User/settings.json"
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
  imports = [ ./devin ];

  # SSH config (this file replaces a hand-written ~/.ssh/config; ad-hoc hosts go in ~/.ssh/config.local)
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "config.local" ];
    settings."github.com" = {
      IdentityFile = "~/.ssh/${machine.sshKey}";
      IdentitiesOnly = "yes";
      AddKeysToAgent = "yes";
      UseKeychain = "yes";
    };
  };

  home.activation.devinEditorSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${editorSettingsMerge}
  '';
}
