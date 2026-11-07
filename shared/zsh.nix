# Shared zsh configuration (NixOS and Darwin): env vars, aliases, direnv hook
{ pkgs, lib, ... }:
let
  env = import ./env.nix;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    
    interactiveShellInit = ''
      ${lib.optionalString isDarwin ''
      # Filter non-existent homebrew completion paths before compinit (macOS only)
      fpath=(''${fpath:#/opt/homebrew/share/zsh/site-functions})
      ''}
      autoload -U compinit && compinit
      
      ${env.vars}
      ${env.aliases}
      
      # `rebuild` is host-specific: each host sets it to its own flake (hosts/<name>)
      alias dev="nix develop ~/homelab/nix"
      
      # Direnv hook (silenced, only if .envrc exists)
      export DIRENV_LOG_FORMAT=""
      if command -v direnv &>/dev/null; then
        eval "$(direnv hook zsh)"
      fi
    '';
  };
}
