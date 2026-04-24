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
        
        # Finder
        finder = {
          AppleShowAllExtensions = true;
          ShowPathbar = true;
          ShowStatusBar = true;
          FXPreferredViewStyle = "Nlsv";
          FXDefaultSearchScope = "SCcf";
        };
        
        # Trackpad
        trackpad = {
          TrackpadRightClick = true;
          TrackpadThreeFingerDrag = true;
        };
        
        # Keyboard
        NSGlobalDomain = {
          KeyRepeat = 2;
          InitialKeyRepeat = 15;
          ApplePressAndHoldEnabled = false;
        };
      };

      # Enable Touch ID for sudo
      security.pam.services.sudo_local.touchIdAuth = true;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Zsh configuration
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        
        interactiveShellInit = ''
          # PATH additions
          export PATH=$PATH:~/.local/bin
          export PATH="$PATH:$GOPATH/bin"
          export PATH="/Users/austin.mills/.codeium/windsurf/bin:$PATH"
          
          # Go
          GOPATH=~/go
          
          # Docker
          export DOCKER_DEFAULT_PLATFORM=linux/amd64
          
          # Zscaler cert overrides
          export NODE_EXTRA_CA_CERTS=~/certs/bundle.crt
          export REQUESTS_CA_BUNDLE=~/certs/bundle.crt
          
          # Aliases
          alias ll="ls -lG"
          alias k="kubectl"
          alias google-auth="gcloud auth login --update-adc"
          alias tf="terraform"
          alias tf-init-all="terraform init && terraform providers lock -platform=darwin_amd64 -platform=darwin_arm64 -platform=linux_arm64 -platform=linux_amd64"
          alias rebuild="sudo darwin-rebuild switch --flake ~/nix#austin-m5-pro"
        '';
      };

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
        # Home Manager
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users."austin.mills" = { pkgs, lib, ... }: {
            home.username = "austin.mills";
            home.homeDirectory = lib.mkForce "/Users/austin.mills";
            home.stateVersion = "24.05";
            
            # Packages
            home.packages = [ pkgs.powerline-go ];
            
            # Powerline-go prompt and completions
            programs.zsh = {
              enable = true;
              initContent = ''
                # Completions
                source <(sparkctl completion zsh)
                source <(valhalla completion zsh)
                source <(kubectl completion zsh)
                
                # Powerline-go prompt
                function powerline_precmd() {
                  PS1="$(powerline-go -error $? -shell zsh)"
                }

                function install_powerline_precmd() {
                  for s in "''${precmd_functions[@]}"; do
                    if [ "$s" = "powerline_precmd" ]; then
                      return
                    fi
                  done
                  precmd_functions+=(powerline_precmd)
                }

                install_powerline_precmd
              '';
            };
            
            # Git configuration
            programs.git = {
              enable = true;
              signing.format = null;
              settings = {
                user.name = "Austin37AF";
                user.email = "austin@cyborgcomputing.net";
                init.defaultBranch = "main";
                push.autoSetupRemote = true;
              };
            };
          };
        }
      ];
    };
  };
}
