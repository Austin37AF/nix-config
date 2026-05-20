{ config, lib, ... }:
let
  cfg = config.k8s-static-ip;
in
{
  options.k8s-static-ip = {
    enable = lib.mkEnableOption "Static IP configuration for K8s node";
    
    address = lib.mkOption {
      type = lib.types.str;
      description = "Static IP address for this node";
    };
    
    prefixLength = lib.mkOption {
      type = lib.types.int;
      default = 24;
      description = "Network prefix length (e.g., 24 for /24)";
    };
    
    gateway = lib.mkOption {
      type = lib.types.str;
      description = "Default gateway IP";
    };
    
    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "1.1.1.1" "8.8.8.8" ];
      description = "DNS nameservers";
    };
    
    interface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
      description = "Network interface name (eth0, enp0s3, etc.)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Disable NetworkManager in favor of systemd-networkd for static config
    networking.networkmanager.enable = lib.mkForce false;
    networking.useDHCP = false;
    
    # Use systemd-networkd for static IP
    systemd.network = {
      enable = true;
      
      networks."10-${cfg.interface}" = {
        matchConfig.Name = cfg.interface;
        networkConfig = {
          Address = "${cfg.address}/${toString cfg.prefixLength}";
          Gateway = cfg.gateway;
          DNS = cfg.nameservers;
          DHCP = "no";
        };
      };
      
      # Wait for network to be configured before starting services
      wait-online.anyInterface = true;
    };
    
    # Ensure resolved uses our DNS servers
    services.resolved = {
      enable = true;
      fallbackDns = cfg.nameservers;
    };
  };
}
