{ pkgs }:
let
  packages = import ./packages.nix { inherit pkgs; };
  env = import ./env.nix;
in
pkgs.mkShell {
  packages = packages.cli ++ packages.dev;
  
  shellHook = ''
    echo "🛠  Dev shell loaded: go, python, opentofu, jq, yq"
    
    ${env.vars}
    ${env.aliases}
    
    # Powerline-go prompt with dev shell indicator
    function _update_ps1() {
      PS1="$(powerline-go -error $? -shell bash -modules "shell-var,kube,cwd,git,exit" -shell-var NIX_SHELL_TAG -shorten-eks-names -shorten-gke-names)"
    }
    export NIX_SHELL_TAG="[dev]"
    PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
  '';
}
