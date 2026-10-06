{ lib, ... }:
{
  # ============================================
  # Server Hardening & Reliability
  # ============================================
  # Best practices for always-on headless K8s nodes

  # Prevent sleep/hibernate/suspend
  powerManagement.enable = false;
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Disable GUI-related power management
  services.xserver.enable = lib.mkForce false;
  
  # Auto-reboot on kernel panic (wait 10 seconds)
  boot.kernelParams = [ "panic=10" ];
  
  # Watchdog - reboot if system hangs
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "30s";
    RebootWatchdogSec = "10m";
  };

  # Updates are pushed with deploy-rs (`nix run .#deploy`) from the pinned flake.lock.
  # No system.autoUpgrade: the repo is private and per-node nixpkgs bumps would drift.

  # Garbage collection to prevent disk fill
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  
  # Optimize nix store
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  # Journal size limits (prevent log disk fill)
  # Persistent storage survives reboots for debugging
  services.journald.settings.Journal = {
    SystemMaxUse = "500M";
    MaxRetentionSec = "1month";
    Storage = "persistent";
  };

  # SMART monitoring for disk health
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.mail.enable = false;  # Set up if you want email alerts
  };

  # Firmware updates
  services.fwupd.enable = true;

  # Firewall hardening
  networking.firewall = {
    enable = true;
    logReversePathDrops = true;
    # Limit SSH brute force
    extraCommands = ''
      iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set
      iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
    '';
  };

  # Fail2ban for SSH protection
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
  };

  # Enable BBR congestion control (better network performance)
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };
}
