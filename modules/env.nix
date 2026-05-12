# Shared environment variables and aliases
{
  # Powerline-go config
  powerlineFlags = "-shorten-eks-names -shorten-gke-names";
  
  # Show namespace in kube prompt (even when 'default')
  showKubeNamespace = false;
  
  powerlineBash = ''
    function _update_ps1() {
      PS1="$(powerline-go -error $? -shell bash -modules "mynix,mykube,cwd,git,exit" -shorten-eks-names -shorten-gke-names)"
    }
    PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
  '';
  
  # Environment variables
  vars = ''
    # PATH additions
    export PATH=$PATH:~/.local/bin
    export GOPATH=~/go
    export PATH="$PATH:$GOPATH/bin"
    
    # Docker
    export DOCKER_DEFAULT_PLATFORM=linux/amd64
    
    # Zscaler cert overrides
    export NODE_EXTRA_CA_CERTS=~/certs/bundle.crt
    export REQUESTS_CA_BUNDLE=~/certs/bundle.crt
    
    # GKE auth plugin
    export USE_GKE_GCLOUD_AUTH_PLUGIN=True
  '';
  
  # Aliases (bash-compatible)
  aliases = ''
    alias ll="ls -lG"
    alias k="kubectl"
    alias k_dd="kubectl config use-context docker-desktop"
    alias google-auth="gcloud auth login --update-adc"
    alias tf="tofu"
    alias terraform="tofu"
    alias tf-init-all="tofu init && tofu providers lock -platform=darwin_amd64 -platform=darwin_arm64 -platform=linux_arm64 -platform=linux_amd64"
  '';
}
