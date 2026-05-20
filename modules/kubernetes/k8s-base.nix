{ pkgs, ... }:
{
  imports = [ 
    ./k8s-node.nix 
    ./static-ip.nix
    ./server-hardening.nix
  ];

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Bootloader for UEFI (Mac Minis use UEFI)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Timezone and locale
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  # Admin user for cluster management
  users.users.k8sadmin = {
    isNormalUser = true;
    description = "Kubernetes Admin";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      # Add your SSH public key here for passwordless access
      # "ssh-ed25519 AAAA... your-key-comment"
    ];
  };

  # Enable passwordless sudo for k8sadmin
  security.sudo.extraRules = [{
    users = [ "k8sadmin" ];
    commands = [{
      command = "ALL";
      options = [ "NOPASSWD" ];
    }];
  }];

  # Enable zsh
  programs.zsh.enable = true;

  # Base system packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    curl
    wget
    tmux
  ];

  # System state version
  system.stateVersion = "24.05";
}
