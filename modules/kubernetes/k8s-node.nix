{ config, pkgs, lib, ... }:
let
  cfg = config.k8s-node;
in
{
  options.k8s-node = {
    enable = lib.mkEnableOption "Kubernetes node configuration";
    
    role = lib.mkOption {
      type = lib.types.enum [ "server" "agent" ];
      default = "agent";
      description = "Whether this node is a k3s server (control plane) or agent (worker)";
    };
    
    serverAddr = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Address of the k3s server (required for agents)";
    };
    
    tokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the k3s token file for cluster join (from sops)";
    };
    
    clusterInit = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Initialize a new cluster (only for first server)";
    };
    
    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra flags to pass to k3s";
    };
  };

  config = lib.mkIf cfg.enable {
    # k3s service
    services.k3s = {
      enable = true;
      role = cfg.role;
      tokenFile = lib.mkIf (cfg.tokenFile != null) cfg.tokenFile;
      clusterInit = cfg.clusterInit;
      serverAddr = lib.mkIf (cfg.role == "agent" || (cfg.role == "server" && !cfg.clusterInit)) cfg.serverAddr;
      extraFlags = cfg.extraFlags;
    };

    # Required for k3s networking
    boot.kernelModules = [ "br_netfilter" "overlay" ];
    boot.kernel.sysctl = {
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
      "net.ipv4.ip_forward" = 1;
    };

    # Open firewall ports for k3s
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [
        6443  # Kubernetes API server
        10250 # Kubelet metrics
        2379  # etcd client (server only)
        2380  # etcd peer (server only)
      ];
      allowedUDPPorts = [
        8472  # Flannel VXLAN
        51820 # Flannel Wireguard (IPv4)
        51821 # Flannel Wireguard (IPv6)
      ];
      # Allow all traffic from pod/service CIDRs
      trustedInterfaces = [ "cni0" "flannel.1" ];
    };

    # Useful CLI tools for K8s management
    environment.systemPackages = with pkgs; [
      k3s
      kubectl
      kubernetes-helm
      k9s
      jq
    ];

    # Enable SSH for remote management
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };

    # Disable swap (required for Kubernetes)
    swapDevices = lib.mkForce [];
    
    # Ensure time sync (critical for K8s)
    services.chrony.enable = true;
  };
}
