{ pkgs }:
let
  packages = import ./packages.nix { inherit pkgs; };
  env = import ./env.nix;
in
pkgs.mkShell {
  packages = packages.cli ++ packages.dev;
  
  shellHook = ''
    # Only show message in interactive shells
    [[ $- == *i* ]] && echo "🛠  Dev shell loaded: go, python, opentofu, jq, yq"
    
    ${env.vars}
    ${env.aliases}
    ${env.powerlineBash}
    
    # Bash completions
    source ${pkgs.bash-completion}/share/bash-completion/bash_completion
    source <(kubectl completion bash)
    complete -o default -F __start_kubectl k
    command -v sparkctl &>/dev/null && source <(sparkctl completion bash)
    command -v valhalla &>/dev/null && source <(valhalla completion bash)
  '';
}
