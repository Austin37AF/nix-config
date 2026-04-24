{ pkgs }: pkgs.mkShell {
  packages = [
    pkgs.go
    pkgs.python3
    pkgs.opentofu
    pkgs.jq
    pkgs.yq
    pkgs.powerline-go
  ];
  
  shellHook = ''
    echo "🛠  Dev shell loaded: go, python, opentofu, jq, yq"
    
    # Aliases
    alias ll="ls -lG"
    alias k="kubectl"
    alias tf="tofu"
    alias terraform="tofu"
    
    # PATH
    export PATH=$PATH:~/.local/bin
    export GOPATH=~/go
    export PATH="$PATH:$GOPATH/bin"
    
    # Docker
    export DOCKER_DEFAULT_PLATFORM=linux/amd64
    
    # Zscaler certs
    export NODE_EXTRA_CA_CERTS=~/certs/bundle.crt
    export REQUESTS_CA_BUNDLE=~/certs/bundle.crt
    
    # Powerline-go prompt with dev shell indicator
    function _update_ps1() {
      PS1="$(powerline-go -error $? -shell bash -modules "shell-var,cwd,git,exit" -shell-var NIX_SHELL_TAG)"
    }
    export NIX_SHELL_TAG="[dev]"
    PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
  '';
}
