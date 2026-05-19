# Darwin-specific zsh additions
{ ... }:
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
      alias rebuild="sudo darwin-rebuild switch --flake ~/nix#austin-m5-pro"
      alias dev="nix develop ~/nix"
      
      # Direnv hook (silenced, only if .envrc exists)
      export DIRENV_LOG_FORMAT=""
      if command -v direnv &>/dev/null; then
        eval "$(direnv hook zsh)"
      fi
    '';
  };
}
