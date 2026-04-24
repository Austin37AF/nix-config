{ ... }: {
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
      
      # PATH additions
      export PATH=$PATH:~/.local/bin
      export PATH="$PATH:$GOPATH/bin"
      export PATH="/Users/austin.mills/.codeium/windsurf/bin:$PATH"
      
      # Go
      GOPATH=~/go
      
      # Docker
      export DOCKER_DEFAULT_PLATFORM=linux/amd64
      
      # Zscaler cert overrides
      export NODE_EXTRA_CA_CERTS=~/certs/bundle.crt
      export REQUESTS_CA_BUNDLE=~/certs/bundle.crt
      
      # Aliases
      alias ll="ls -lG"
      alias k="kubectl"
      alias google-auth="gcloud auth login --update-adc"
      alias tf="tofu"
      alias terraform="tofu"
      alias tf-init-all="tofu init && tofu providers lock -platform=darwin_amd64 -platform=darwin_arm64 -platform=linux_arm64 -platform=linux_amd64"
      alias rebuild="sudo darwin-rebuild switch --flake ~/nix#austin-m5-pro"
      alias dev="nix develop ~/nix"
      
      # Direnv
      eval "$(direnv hook zsh)"
    '';
  };
}
