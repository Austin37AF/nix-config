{ pkgs, ... }:
let
  commonPackages = import ../common/packages.nix { inherit pkgs; };
in
{
  # System packages
  environment.systemPackages = commonPackages.cli ++ [
    pkgs.vim
    pkgs.git
    pkgs.vscode
    pkgs.slack
    pkgs.google-chrome
    pkgs.adwaita-icon-theme
  ];
  
  # Fonts
  fonts.packages = commonPackages.fonts;

  # Enable zsh system-wide
  programs.zsh.enable = true;

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Bootloader - adjust based on your hardware
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "nixos-laptop";
  networking.networkmanager.enable = true;

  # Timezone and locale
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  # Desktop environment (GNOME)
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # User account
  users.users.austinm = {
    isNormalUser = true;
    description = "Austin";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.zsh;
  };

  # Enable Docker
  virtualisation.docker.enable = true;

  # Fingerprint reader (Goodix)
  services.fprintd.enable = true;

  # System state version - don't change after initial install
  system.stateVersion = "24.05";
}
