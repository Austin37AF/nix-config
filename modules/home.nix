{ pkgs, lib, ... }:
let
  env = import ./env.nix;
in
{
  home.username = "austin.mills";
  home.homeDirectory = lib.mkForce "/Users/austin.mills";
  home.stateVersion = "24.05";
  
  # Packages
  home.packages = [ pkgs.powerline-go ];
  
  # Nix shell wrapper for Windsurf terminal
  home.file.".local/bin/zsh-nix" = {
    executable = true;
    text = ''
#!/bin/zsh -l
# Enter nix shell, then fall back to regular zsh when exited
nix develop /Users/austin.mills/nix --quiet --no-warn-dirty --command /bin/zsh -l
# After nix shell exits, stay in regular zsh
exec /bin/zsh -l
    '';
  };
  
  
  # Custom powerline-go scripts
  home.file.".local/bin/powerline-go-mynix" = {
    executable = true;
    text = ''
#!/bin/bash
# Show nix indicator - devbox gets package, nix develop gets snowflake
if [ -n "$DEVBOX_SHELL_ENABLED" ]; then
    echo '[{"Content": "📦", "Foreground": 15, "Background": 99}]'
elif [ -n "$IN_NIX_SHELL" ]; then
    echo '[{"Content": "❄️", "Foreground": 15, "Background": 33}]'
fi
    '';
  };

  home.file.".local/bin/powerline-go-mykube" = {
    executable = true;
    text = ''
#!/bin/bash

# Get the current kube context
CURRENT_CTX=$(kubectl config current-context 2>/dev/null)

# If there is no context, exit silently so powerline-go just skips this block
if [ -z "$CURRENT_CTX" ]; then
    exit 0
fi

# Map the context to your preferred Name, Foreground (FG), and Background (BG)
case "$CURRENT_CTX" in
    "docker-desktop")
        CONTENT="󰡨"
        FG=15
        BG=24
        ;;
    "minikube")
        CONTENT="mini"
        FG=161
        BG=15
        ;;
    "gke_sparkai-infra_us-central1_infra-cluster")
        CONTENT="GCP-INFRA"
        FG=15
        BG=161
        ;;
    "gke_sparkai-prod_us-central1_prod-cluster")
        CONTENT="GCP-PROD"
        FG=7
        BG=160
        ;;
    "gke_sparkai-staging_us-central1_staging-cluster")
        CONTENT="GCP-STAGING"
        FG=0
        BG=148
        ;;
    "arn:aws:eks:us-east-1:975050219078:cluster/brtplat-dev")
        CONTENT="brtplat-dev"
        FG=0
        BG=148
        ;;
    "arn:aws:eks:us-east-1:381492297234:cluster/brtplat-infra")
        CONTENT="brtplat-infr"
        FG=15
        BG=161
        ;;
    "arn:aws:eks:us-east-1:471112691876:cluster/brtplat-prod")
        CONTENT="brt-prod"
        FG=7
        BG=160
        ;;
    *)
        # Default fallback for unmapped contexts
        CONTENT="$CURRENT_CTX"
        FG=250
        BG=236
        ;;
esac

# Get the current namespace
CURRENT_NS=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
if [ -z "$CURRENT_NS" ]; then
    CURRENT_NS="default"
fi

# Output segments - include namespace based on config
SHOW_NS="${if env.showKubeNamespace then "true" else "false"}"
if [ "$SHOW_NS" = "true" ] || [ "$CURRENT_NS" != "default" ]; then
    cat <<EOF
[
  {"Content": "$CONTENT", "Foreground": $FG, "Background": $BG},
  {"Content": "$CURRENT_NS", "Foreground": 15, "Background": 238}
]
EOF
else
    cat <<EOF
[{"Content": "$CONTENT", "Foreground": $FG, "Background": $BG}]
EOF
fi
    '';
  };
  
  # Powerline-go prompt and completions
  programs.zsh = {
    enable = true;
    enableCompletion = false;  # Handled by nix-darwin in /etc/zshrc
    initContent = ''
      # Completions (guarded to prevent hanging)
      command -v sparkctl &>/dev/null && source <(sparkctl completion zsh)
      command -v valhalla &>/dev/null && source <(valhalla completion zsh)
      command -v kubectl &>/dev/null && source <(kubectl completion zsh)
      
      # Powerline-go prompt
      function powerline_precmd() {
        local exit_code=$?
        PS1="$(powerline-go -error $exit_code -shell zsh -modules mynix,mykube,cwd,git,exit ${env.powerlineFlags})"
      }

      function install_powerline_precmd() {
        for s in "''${precmd_functions[@]}"; do
          if [ "$s" = "powerline_precmd" ]; then
            return
          fi
        done
        precmd_functions=(powerline_precmd "''${precmd_functions[@]}")
      }

      install_powerline_precmd
    '';
  };
  
  # Windsurf settings
  home.file."Library/Application Support/Windsurf/User/settings.json" = {
    force = true;
    text = builtins.toJSON {
      "security.workspace.trust.untrustedFiles" = "open";
      "files.autoSave" = "onFocusChange";
      "terminal.integrated.fontFamily" = "JetBrainsMono Nerd Font";
      "terminal.integrated.defaultProfile.osx" = "zsh-nix";
      "terminal.integrated.profiles.osx" = {
        bash = { path = "/bin/bash"; args = ["-l"]; };
        zsh = { path = "/bin/zsh"; args = ["-l"]; };
        zsh-nix = { path = "/Users/austin.mills/.local/bin/zsh-nix"; };
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
  
  # Git configuration
  programs.git = {
    enable = true;
    signing.format = null;
    settings = {
      user.name = "Austin37AF";
      user.email = "austin@cyborgcomputing.net";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };
  
}
