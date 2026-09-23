{ pkgs }: 
let
  orca = pkgs.stdenv.mkDerivation rec {
    pname = "orca";
    version = "1.4.141";
    
    src = pkgs.fetchurl {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-macos-arm64.dmg";
      hash = "sha256-c5+eSUNpKXxSr9m6xuyU4S5dbBPyUuw6aPRgz8AICEc=";
    };
    
    nativeBuildInputs = [ pkgs.undmg ];
    sourceRoot = ".";
    
    installPhase = ''
      mkdir -p $out/Applications
      cp -r Orca.app $out/Applications/
    '';
    
    meta = {
      description = "IDE for orchestrating AI coding agents";
      homepage = "https://onorca.dev";
      platforms = [ "aarch64-darwin" ];
    };
  };
in
{
  # macOS GUI apps
  gui = [
    orca
    pkgs.vim
    pkgs.mkalias
    pkgs.obsidian
    pkgs.alt-tab-macos
    pkgs.hidden-bar
    pkgs.rectangle
    # pkgs.stats  # Moved to Homebrew - nixpkgs version crashes due to code signing issues
    pkgs.the-unarchiver
  ];
}
