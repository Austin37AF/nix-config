# Shared zsh configuration (works on both Darwin and NixOS)
{ pkgs, lib, ... }:
let
  env = import ./env.nix;
  isDarwin = pkgs.stdenv.isDarwin;
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
      
      # Platform-specific rebuild alias
      ${if isDarwin then ''
      alias rebuild="sudo darwin-rebuild switch --flake ~/nix#austin-m5-pro"
      alias rebuild-home="sudo darwin-rebuild switch --flake ~/nix#austin-m5-pro-home"
      '' else ''
      alias rebuild="sudo nixos-rebuild switch --flake ~/nix#nixos-laptop"
      ''}
      alias dev="nix develop ~/nix"
      
      # Direnv hook (silenced, only if .envrc exists)
      export DIRENV_LOG_FORMAT=""
      if command -v direnv &>/dev/null; then
        eval "$(direnv hook zsh)"
      fi
    '';
  };
}
