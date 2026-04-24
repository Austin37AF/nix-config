{ ... }:
let
  env = import ./env.nix;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    
    interactiveShellInit = ''
      # Filter homebrew from fpath in nix/devbox shells to avoid compinit errors
      if [ -n "$DEVBOX_SHELL_ENABLED" ] || [ -n "$IN_NIX_SHELL" ]; then
        fpath=(''${fpath:#/opt/homebrew/*})
      fi
      
      # Set shell tag for devbox shells (for powerline-go prompt)
      if [ -n "$DEVBOX_SHELL_ENABLED" ]; then
        export NIX_SHELL_TAG='[devbox]'
      fi
      
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
