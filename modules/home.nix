{ pkgs, lib, ... }: {
  home.username = "austin.mills";
  home.homeDirectory = lib.mkForce "/Users/austin.mills";
  home.stateVersion = "24.05";
  
  # Packages
  home.packages = [ pkgs.powerline-go ];
  
  # Powerline-go prompt and completions
  programs.zsh = {
    enable = true;
    initContent = ''
      # Completions
      source <(sparkctl completion zsh)
      source <(valhalla completion zsh)
      source <(kubectl completion zsh)
      
      # Powerline-go prompt
      function powerline_precmd() {
        if [ -n "$NIX_SHELL_TAG" ]; then
          PS1="$(powerline-go -error $? -shell zsh -modules shell-var,kube,cwd,git,exit -shell-var NIX_SHELL_TAG -shorten-eks-names -shorten-gke-names)"
        else
          PS1="$(powerline-go -error $? -shell zsh -modules kube,cwd,git,exit -shorten-eks-names -shorten-gke-names)"
        fi
      }

      function install_powerline_precmd() {
        for s in "''${precmd_functions[@]}"; do
          if [ "$s" = "powerline_precmd" ]; then
            return
          fi
        done
        precmd_functions+=(powerline_precmd)
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
