{
  description = "austin-m5-pro: work MacBook (nix-darwin + home-manager)";

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

    # Homelab CLI (cluster ops, `heimdall ai` for the local LLM server)
    heimdall.url = "git+ssh://git@github.com/Austin37AF/heimdall";
    heimdall.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Rebuild: `rebuild` (work) / `rebuild-home` (personal), see ./zsh.nix
  outputs = { self, nix-darwin, nix-homebrew, home-manager, homebrew-core, homebrew-cask, heimdall, ... }:
  let
    # Per-machine settings, passed to modules as `machine`
    #   name:    default darwinConfiguration for `rebuild`
    #   sshKey:  this machine's GitHub SSH key (~/.ssh/<sshKey>), one key per machine
    #   hasHome: also has a `<name>-home` config (`rebuild-home`)
    machine = { name = "austin-m5-pro"; sshKey = "austin-m5-pro"; hasHome = true; };

    mkDarwin = extraModules: nix-darwin.lib.darwinSystem {
      specialArgs = { inherit machine; };
      modules = baseModules ++ extraModules;
    };

    baseModules = [
      ./default.nix
      ./homebrew.nix
      ./zsh.nix
      ./local-ai/darwin.nix

      { system.configurationRevision = self.rev or self.dirtyRev or null; }
      { environment.systemPackages = [ heimdall.packages.aarch64-darwin.default ]; }

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
          mutableTaps = true;
        };
      }

      ({ config, lib, ... }: {
        homebrew.taps = lib.mkAfter (builtins.attrNames config.nix-homebrew.taps);
      })

      home-manager.darwinModules.home-manager
      ({ machine, ... }: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "hm-backup";
        home-manager.extraSpecialArgs = { inherit machine; };
        home-manager.users."austin.mills" = { ... }: {
          imports = [
            ../../shared/home.nix
            ./home.nix
            ./local-ai/home.nix
          ];
        };
      })
    ];
  in {
    darwinConfigurations = {
      # Work mode (default): Zscaler, work Homebrew, work Devin config, direnv
      "austin-m5-pro" = mkDarwin [ ./work ];

      # Personal mode (no work modules)
      "austin-m5-pro-home" = mkDarwin [ ];
    };
  };
}
