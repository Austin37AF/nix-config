{
  description = "Austin's Nix configurations for Darwin and NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative tap management (Darwin only)
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
  let
    # Darwin pkgs
    darwinPkgs = import nixpkgs {
      system = "aarch64-darwin";
      config.allowUnfree = true;
    };
    # NixOS pkgs
    nixosPkgs = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
  in
  {
    # Dev shell for projects without their own Devbox
    devShells.aarch64-darwin.default = import ./modules/devshell.nix { pkgs = darwinPkgs; };
    devShells.x86_64-linux.default = import ./modules/devshell.nix { pkgs = nixosPkgs; };

    # ============================================
    # Darwin Configuration (macOS)
    # ============================================
    darwinConfigurations."austin-m5-pro" = nix-darwin.lib.darwinSystem {
      modules = [
        # Core modules
        ./modules/darwin/default.nix
        ./modules/darwin/homebrew.nix
        ./modules/darwin/zsh.nix
        
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
          home-manager.users."austin.mills" = { ... }: {
            imports = [
              ./modules/common/home.nix
              ./modules/darwin/home.nix
            ];
          };
        }
      ];
    };

    # ============================================
    # NixOS Configuration (Linux laptop)
    # ============================================
    nixosConfigurations."nixos-laptop" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Hardware config (replace with your actual hardware)
        ./modules/nixos/hardware-configuration.nix
        
        # Core modules
        ./modules/nixos/default.nix
        ./modules/nixos/zsh.nix
        
        # Home Manager
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.austin = import ./modules/common/home.nix;
        }
      ];
    };
  };
}
