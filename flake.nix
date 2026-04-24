{
  description = "Austin nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative tap management
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, home-manager, homebrew-core, homebrew-cask }:
  {
    darwinConfigurations."austin-m5-pro" = nix-darwin.lib.darwinSystem {
      modules = [
        # Core modules
        ./modules/darwin.nix
        ./modules/homebrew.nix
        ./modules/zsh.nix
        
        # Set git revision
        { system.configurationRevision = self.rev or self.dirtyRev or null; }
        
        # nix-homebrew
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            user = "austin.mills";
            autoMigrate = true;
            enableRosetta = true;
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
            };
            mutableTaps = false;
          };
        }
        
        # Align homebrew taps config with nix-homebrew
        ({ config, ... }: {
          homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
        })
        
        # Home Manager
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users."austin.mills" = import ./modules/home.nix;
        }
      ];
    };
  };
}
