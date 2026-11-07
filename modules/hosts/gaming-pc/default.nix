# Gaming PC: Ryzen 7 2700X, GTX 1060 6GB, KDE Plasma 6, Steam / Battle.net (via Lutris)
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../common/zsh.nix
    # OS disk (SATA SSD). nixos-anywhere WIPES it: verify the device with lsblk on the installer before install.
    (import ../../kubernetes/disko.nix { device = "/dev/sda"; })
  ];

  # Games disk (NVMe) is deliberately NOT in disko, so re-running nixos-anywhere never wipes it.
  # scripts/install-gaming-pc.sh formats it once (label "games") if the label doesn't exist yet.
  fileSystems."/games" = {
    device = "/dev/disk/by-label/games";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.device-timeout=10s" ];
  };
  systemd.tmpfiles.rules = [ "d /games 0755 austin users -" ];

  networking.hostName = "gaming-pc";
  networking.networkmanager.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nixpkgs.config.allowUnfree = true;

  zramSwap.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    # Pascal (GTX 10xx) support was dropped after the 580 branch, and the open
    # kernel modules need Turing or newer, so use the proprietary 580 legacy driver.
    open = false;
    modesetting.enable = true;
    powerManagement.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };

  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  programs.firefox.enable = true;

  programs.steam = {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    lutris
    winetricks
    mangohud
    vim
    git
    htop
  ];

  programs.zsh.enable = true;
  users.users.austin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "gamemode" "video" ];
    shell = pkgs.zsh;
    # Change with `passwd` on first login
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = (import ../../kubernetes/cluster-config.nix).sshPublicKeys;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  system.stateVersion = "26.11";
}
