{ ... }:
let
  env = import ./env.nix;
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
      
      # Direnv
      eval "$(direnv hook zsh)"
    '';
  };
}
