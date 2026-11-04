{ pkgs }:
let
  packages = import ./common/packages.nix { inherit pkgs; };
  env = import ./common/env.nix;
  
  # Devin CLI - fetched directly from official distribution
  devin-cli = pkgs.stdenv.mkDerivation rec {
    pname = "devin-cli";
    version = "3000.2.17";
    
    src = pkgs.fetchurl {
      url = "https://static.devin.ai/cli/${version}/devin-${version}-aarch64-apple-darwin.tar.gz";
      sha256 = "60e2edd321f5cd5e1cfdf3d6d5e12064f25326ca8e36a8ad71f43d000745dff8";
    };
    
    sourceRoot = ".";
    
    installPhase = ''
      mkdir -p $out/bin
      cp -r bin/devin $out/bin/devin-cli
      chmod +x $out/bin/devin-cli
    '';
    
    meta = {
      description = "Devin CLI - local coding agent";
      homepage = "https://devin.ai";
      platforms = [ "aarch64-darwin" ];
    };
  };
in
pkgs.mkShell {
  packages = packages.cli ++ packages.dev
    # devin-cli is only distributed as an aarch64-darwin binary
    ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ devin-cli ];
  
  shellHook = ''
    # Only show message in interactive shells
    [[ $- == *i* ]] && echo "🛠  Dev shell loaded: go, python, opentofu, jq, yq"

    ${env.vars}

    # Homebrew (for packages not available/broken in nixpkgs, e.g. gimme-aws-creds)
    export PATH="/opt/homebrew/bin:$PATH"

    # BRT devkit (only in dev shell)
    export PATH="$PATH:~/.venvs/brt/bin"

    # Interactive-only setup. Skipped under direnv (DIRENV_IN_ENVRC=1), which
    # evaluates this hook non-interactively to capture the environment.
    if [ -z "''${DIRENV_IN_ENVRC:-}" ]; then
      ${env.aliases}
      ${env.powerlineBash}

      alias brt="source ~/.venvs/brt/bin/activate"

      # Bash completions
      source ${pkgs.bash-completion}/share/bash-completion/bash_completion
      source <(kubectl completion bash)
      complete -o default -F __start_kubectl k
      command -v sparkctl &>/dev/null && source <(sparkctl completion bash)
      command -v valhalla &>/dev/null && source <(valhalla completion bash)
    fi
  '';
}
