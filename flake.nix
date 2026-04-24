{
  description = "Austin nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

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

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, homebrew-core, homebrew-cask }:
  let
    configuration = { pkgs, config, ... }: {
      nixpkgs.config.allowUnfree = true;
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        [ 
          pkgs.vim
          pkgs.mkalias
          pkgs.obsidian
          pkgs.alt-tab-macos
          pkgs.hidden-bar
          pkgs.rectangle
          pkgs.stats
          pkgs.the-unarchiver
        ];
      
      system.activationScripts.applications.text = let
	env = pkgs.buildEnv {
	  name = "system-applications";
	  paths = config.environment.systemPackages;
	  pathsToLink = [ "/Applications" ];
	};
      in
	pkgs.lib.mkForce ''
	  # Set up applications.
	  echo "setting up /Applications..." >&2
	  rm -rf /Applications/Nix\ Apps
	  mkdir -p /Applications/Nix\ Apps
	  find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
	  while read -r src; do
	    app_name=$(basename "$src")
	    echo "copying $src" >&2
	    ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
	  done
	'';

      system.defaults = {
        dock = {
          autohide = true;
          show-process-indicators = false;
          persistent-apps = [
            "${pkgs.obsidian}/Applications/Obsidian.app"
            "/Applications/Google Chrome.app"
            "/Applications/Slack.app"
            "/Applications/Docker.app"
            "/Applications/Windsurf.app"
            "/System/Applications/Utilities/Terminal.app"
            "/System/Applications/Notes.app"
          ];
        };
        screencapture = {
          location = "/Users/austin.mills/Pictures/Screenshots";
        };
      };

      # Enable Touch ID for sudo
      security.pam.services.sudo_local.touchIdAuth = true;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      # Required for homebrew and other user-specific options
      system.primaryUser = "austin.mills";

      # Homebrew configuration
      homebrew = {
        enable = true;
        onActivation.cleanup = "zap";
        onActivation.autoUpdate = true;
        onActivation.upgrade = true;
        brews = [
          "awscli"
          "gh"
          "gimme-aws-creds"
          "k9s"
          "pre-commit"
          "mas"
        ];
        casks = [
          "docker-desktop"
          "gcloud-cli"
          "google-drive"
        ];
      };
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
    darwinConfigurations."austin-m5-pro" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
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
        ({config, ...}: {
          homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
        })
      ];
    };
  };
}
