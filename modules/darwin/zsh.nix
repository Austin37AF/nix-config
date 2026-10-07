# Darwin-specific zsh additions
{ lib, machine, ... }:
let
  env = import ../common/env.nix;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableGlobalCompInit = false;  # We'll run compinit manually after filtering fpath
    
    interactiveShellInit = ''
      # Filter non-existent homebrew completion paths before compinit
      fpath=(''${fpath:#/opt/homebrew/share/zsh/site-functions})
      autoload -U compinit && compinit
      
      # Windsurf PATH (zsh only)
      export PATH="/Users/austin.mills/.codeium/windsurf/bin:$PATH"
      
      ${env.vars}
      ${env.aliases}
      
      # Zsh-only aliases
      # Touch GitHub first so AddKeysToAgent loads the key root will use via SSH_AUTH_SOCK
      alias rebuild="ssh -o BatchMode=yes -T git@github.com >/dev/null 2>&1; sudo darwin-rebuild switch --flake ~/homelab/nix#${machine.name}"
      ${lib.optionalString (machine.hasHome or false) ''
      alias rebuild-home="ssh -o BatchMode=yes -T git@github.com >/dev/null 2>&1; sudo darwin-rebuild switch --flake ~/homelab/nix#${machine.name}-home"
      ''}
      alias dev="nix develop ~/homelab/nix"
      
      # Direnv hook (silenced, only if .envrc exists)
      export DIRENV_LOG_FORMAT=""
      if command -v direnv &>/dev/null; then
        eval "$(direnv hook zsh)"
      fi
    '';
  };
}
