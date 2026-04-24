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
    ${env.powerlineBash}
  '';
}
