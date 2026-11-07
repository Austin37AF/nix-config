{ pkgs, lib, modulesPath, ... }:
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
    # Menu-driven install of any NixOS host in hosts/ (see ./install-host.sh)
    (writeShellApplication {
      name = "install-host";
      runtimeInputs = [ git jq disko sops openssh util-linux e2fsprogs ];
      text = builtins.readFile ./install-host.sh;
    })
  ];

  services.getty.helpLine = lib.mkAfter ''

    To install a machine from nix-config, run: install-host
    (ssh -A root@<this-ip> first so the private repos can be cloned)
  '';

  # SSH for install-host over SSH and nixos-anywhere
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  
  # Allow SSH with your key (no password needed)
  users.users.root.openssh.authorizedKeys.keys = import ../shared/ssh-keys.nix;
  
  # Fallback password if SSH key not set yet
  # (the installer profile sets an empty initialHashedPassword; clear it so only one is set)
  users.users.root.initialHashedPassword = lib.mkForce null;
  users.users.root.initialPassword = "nixos";
  users.users.nixos.initialHashedPassword = lib.mkForce null;
  users.users.nixos.initialPassword = "nixos";

  # DHCP for initial boot (hosts apply their own network config after install)
  networking.networkmanager.enable = true;

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
