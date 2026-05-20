{ pkgs, modulesPath, ... }:
let
  clusterCfg = import ./cluster-config.nix;
in
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # Faster ISO builds during development
  isoImage.squashfsCompression = "gzip -Xcompression-level 1";

  # Tools for installation and debugging
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    parted
    gptfdisk
    dosfstools
    e2fsprogs
  ];

  # Enable SSH for nixos-anywhere
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  
  # Allow SSH with your key (no password needed)
  users.users.root.openssh.authorizedKeys.keys = clusterCfg.sshPublicKeys;
  
  # Fallback password if SSH key not set yet
  users.users.root.initialPassword = "nixos";
  users.users.nixos.initialPassword = "nixos";

  # DHCP for initial boot (static IP applied after install)
  networking.networkmanager.enable = true;

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
