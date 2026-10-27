# Darwin-specific home-manager settings
{ machine, ... }: {
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

  # Devin Desktop (formerly Windsurf) editor settings (macOS only)
  home.file."Library/Application Support/Devin/User/settings.json" = {
    force = true;
    text = builtins.toJSON {
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
  };
}
