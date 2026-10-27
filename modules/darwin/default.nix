{ pkgs, config, ... }:
let
  commonPackages = import ../common/packages.nix { inherit pkgs; };
  darwinPackages = import ./packages.nix { inherit pkgs; };
in
{
  imports = [ ./cert-pem.nix ];

  # System packages
  environment.systemPackages = commonPackages.cli ++ darwinPackages.gui;
  
  # Fonts
  fonts.packages = commonPackages.fonts;

  # Private flake inputs (heimdall) are fetched over SSH by `sudo darwin-rebuild`,
  # which runs as root: keep the user's SSH agent and trust GitHub's host key.
  security.sudo.extraConfig = ''
    Defaults env_keep += "SSH_AUTH_SOCK"
  '';
  programs.ssh.knownHosts.github = {
    hostNames = [ "github.com" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };
  
  # Application aliases for Spotlight
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

  # macOS system defaults
  system.defaults = {
    dock = {
      autohide = true;
      show-process-indicators = false;
      persistent-apps = [
        "${pkgs.obsidian}/Applications/Obsidian.app"
        "/Applications/Google Chrome.app"
        "/Applications/Slack.app"
        "/Applications/Docker.app"
        "/Applications/Devin.app"
        "/System/Applications/Utilities/Terminal.app"
        "/System/Applications/Notes.app"
      ];
    };
    
    screencapture = {
      location = "/Users/austin.mills/Pictures/Screenshots";
    };
    
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "Nlsv";
      FXDefaultSearchScope = "SCcf";
    };
    
    trackpad = {
      TrackpadRightClick = true;
    };
    
    NSGlobalDomain = {
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      ApplePressAndHoldEnabled = false;
    };
    
    # Disable Spotlight shortcut (CMD+Space) for Raycast
    CustomUserPreferences = {
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          "64" = { enabled = false; };
          "65" = { enabled = false; };
        };
      };
    };
  };

  # Security
  security.pam.services.sudo_local.touchIdAuth = true;

  # Nix settings
  nix.settings.experimental-features = "nix-command flakes";
  # Note: Zscaler SSL cert is configured in ../common/zscaler.nix (imported in flake.nix for work machines)
  
  # Garbage collection
  nix.gc = {
    automatic = true;
    interval = { Weekday = 0; Hour = 2; Minute = 0; };
    options = "--delete-older-than 14d";
  };

  # Platform
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;
  
  # User
  system.primaryUser = "austin.mills";
  system.stateVersion = 6;
}
