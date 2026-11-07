# Kubernetes Cluster Configuration
# 
# This file contains all cluster-wide settings in one place.
# Update these values before building ISOs or deploying nodes.
#
# SETUP CHECKLIST:
#   1. Generate token: openssl rand -hex 32
#   2. Add your SSH public key below
#   3. Update IPs to match your network
#   4. Push to GitHub, then build ISOs
{
  # ============================================
  # Admin SSH Key (REQUIRED)
  # ============================================
  # Add your public key for passwordless SSH access
  # Get it with: cat ~/.ssh/id_ed25519.pub
  sshPublicKeys = import ../../shared/ssh-keys.nix;

  # ============================================
  # Network Configuration
  # ============================================
  network = {
    gateway = "10.17.17.1";  # Verify this is your router
    prefixLength = 24;
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    # Network interface name on Mac Minis (check with: ip link after booting ISO)
    # Common on Mac Minis: enp1s0f0, en0, eth0
    interface = "enp1s0f0";
  };

  # ============================================
  # Hardware (4x Mac mini Late 2014, A1347, 16GB RAM, 500GB disk)
  # ============================================
  # Disk that the installer WIPES and installs to. Check with `lsblk` on the
  # booted installer (the USB stick may also show up as /dev/sdX).
  # Override per node by adding `disk = "/dev/...";` to a node below.
  defaultDisk = "/dev/sda";

  # ============================================
  # Node IP Assignments
  # ============================================
  # Reserve these IPs in your router's DHCP settings
  nodes = {
    k8s-server-1 = {
      ip = "10.17.17.100";
      role = "server";
      clusterInit = true;  # First node initializes the cluster
    };
    k8s-server-2 = {
      ip = "10.17.17.101";
      role = "server";
      clusterInit = false;
    };
    k8s-server-3 = {
      ip = "10.17.17.102";
      role = "server";
      clusterInit = false;
    };
    k8s-agent-1 = {
      ip = "10.17.17.103";
      role = "agent";
      clusterInit = false;
    };
  };

  # ============================================
  # K3s Configuration  
  # ============================================
  k3s = {
    # Cluster token is stored encrypted in secrets/k8s.yaml (via sops-nix)
    # See README.md for setup instructions
    
    # API server address (use server-1 IP, or a load balancer VIP)
    serverAddr = "https://10.17.17.100:6443";
    
    # TLS SANs - all IPs/hostnames that can reach the API server
    tlsSans = [
      "10.17.17.100"
      "10.17.17.101" 
      "10.17.17.102"
      "k8s.local"  # Optional: add DNS name if you set one up
    ];
  };
}
