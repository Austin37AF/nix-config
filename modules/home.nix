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
  
  # Powerline-go prompt and completions
  programs.zsh = {
    enable = true;
    initContent = ''
      # Completions (guarded to prevent hanging)
      command -v sparkctl &>/dev/null && source <(sparkctl completion zsh)
      command -v valhalla &>/dev/null && source <(valhalla completion zsh)
      command -v kubectl &>/dev/null && source <(kubectl completion zsh)
      
      # Powerline-go prompt
      function powerline_precmd() {
        local exit_code=$?
        if [ -n "$NIX_SHELL_TAG" ]; then
          PS1="$(powerline-go -error $exit_code -shell zsh -modules shell-var,kube,cwd,git,exit -shell-var NIX_SHELL_TAG ${env.powerlineFlags})"
        else
          PS1="$(powerline-go -error $exit_code -shell zsh -modules kube,cwd,git,exit ${env.powerlineFlags})"
        fi
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
