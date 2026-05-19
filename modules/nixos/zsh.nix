# NixOS-specific zsh configuration
{ ... }:
let
  env = import ../common/env.nix;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    
    interactiveShellInit = ''
      autoload -U compinit && compinit
      
      ${env.vars}
      ${env.aliases}
      
      # NixOS rebuild alias
      alias rebuild="sudo nixos-rebuild switch --flake ~/nix#nixos-laptop"
      alias dev="nix develop ~/nix"
      
      # Direnv hook (silenced)
      export DIRENV_LOG_FORMAT=""
      if command -v direnv &>/dev/null; then
        eval "$(direnv hook zsh)"
      fi
    '';
  };
}
