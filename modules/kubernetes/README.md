# Kubernetes Cluster Deployment

NixOS-based k3s cluster with 3 control plane nodes + 1 worker (HA setup).

## Prerequisites

- 4x Mac mini Late 2014 (A1347, 16GB RAM, 500GB disk). Hardware settings are in `hardware.nix`.
- USB drive for installer ISO
- Network with DHCP (for initial boot) and reserved IPs for nodes

## Quick Start

### 1. Enter Devbox Shell (on your workstation)

```bash
# From the repo root (not on the Mac Minis)
devbox shell
```

This provides: `sops`, `age`, `ssh-to-age`, `kubectl`, `helm`, `k9s`, `jq`

### 2. Set Up Secrets (sops-nix)

```bash
# Generate your personal age key (one time)
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# Note your public key (starts with "age1...")
cat ~/.config/sops/age/keys.txt | grep "public key"

# Update .sops.yaml with your public key (replace the placeholder)
vim .sops.yaml

# Create the encrypted secrets file
sops secrets/k8s.yaml
# In the editor, add:
#   k3s-token: "<output of: openssl rand -hex 32>"
# Save and exit - file is now encrypted
```

### 3. Configure the Cluster

Edit `cluster-config.nix`:

- `sshPublicKeys` - Your SSH public key (`cat ~/.ssh/id_ed25519.pub`)
- `network.gateway` - Your router IP
- `network.interface` - NIC name (usually `enp0s3` or `eth0`)
- `nodes.*.ip` - Static IPs for each node

### 4. Build the Installer ISO

```bash
nix build .#k8s-installer-iso
```

The ISO will be at `./result/iso/nixos-*.iso`

### 5. Create Bootable USB

**Option A: Use the flash script (recommended)**
```bash
./scripts/flash-usb.sh
```

**Option B: Manual dd**
```bash
# List disks and find your USB (look for the correct size)
diskutil list

# Unmount and write ISO (replace N with your USB disk number)
diskutil unmountDisk /dev/diskN
sudo dd if=./result/iso/nixos-*.iso of=/dev/rdiskN bs=4m status=progress
diskutil eject /dev/diskN
```

⚠️ **Warning:** Double-check the disk number! Writing to the wrong disk will erase it.

### 6. Initial Deployment (nixos-anywhere)

Boot each Mac Mini from the USB. It will get a DHCP IP.

**Find the IP:** Check your router's DHCP leases, or connect a monitor and run `ip addr`.

**Check the disk and NIC first.** nixos-anywhere **wipes** the disk set in `cluster-config.nix`
(`defaultDisk = "/dev/sda"`, or a per-node `disk`) and partitions it with `disko.nix`
(512M EFI + ext4 root). On the booted installer:

```bash
ssh root@<IP> lsblk -o NAME,SIZE,MODEL,TRAN   # internal ~500G SATA disk, not the USB stick
ssh root@<IP> ip -br link                     # ethernet name for network.interface
```

If the internal disk isn't `/dev/sda`, set `disk = "/dev/sdX";` on that node.

**Deploy in order** (server-1 must be first):

```bash
# Control plane (first node initializes the cluster)
nix run github:nix-community/nixos-anywhere -- --flake .#k8s-server-1 root@<IP>

# Wait for server-1 to reboot and k3s to start (~2 min), then:
nix run github:nix-community/nixos-anywhere -- --flake .#k8s-server-2 root@<IP>
nix run github:nix-community/nixos-anywhere -- --flake .#k8s-server-3 root@<IP>

# Worker node (after all servers are up)
nix run github:nix-community/nixos-anywhere -- --flake .#k8s-agent-1 root@<IP>
```

### 7. Add Node Host Keys to Sops (Important!)

After initial deployment, add each node's SSH key so they can decrypt secrets:

```bash
# Get each node's age-compatible public key
ssh-keyscan -t ed25519 192.168.1.100 2>/dev/null | ssh-to-age
ssh-keyscan -t ed25519 192.168.1.101 2>/dev/null | ssh-to-age
ssh-keyscan -t ed25519 192.168.1.102 2>/dev/null | ssh-to-age
ssh-keyscan -t ed25519 192.168.1.103 2>/dev/null | ssh-to-age

# Add these keys to .sops.yaml, then re-encrypt secrets:
sops updatekeys secrets/k8s.yaml
```

### 8. Verify Cluster

SSH into any server node:

```bash
ssh k8sadmin@192.168.1.100

# Check nodes
sudo k3s kubectl get nodes

# Should show:
# k8s-server-1   Ready    control-plane,etcd,master   
# k8s-server-2   Ready    control-plane,etcd,master   
# k8s-server-3   Ready    control-plane,etcd,master   
# k8s-agent-1    Ready    <none>
```

## Cluster Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     k3s HA Cluster                          │
├───────────────┬───────────────┬───────────────┬────────────┤
│  k8s-server-1 │  k8s-server-2 │  k8s-server-3 │ k8s-agent-1│
│  192.168.1.100│  192.168.1.101│  192.168.1.102│ 192.168.1.103
├───────────────┼───────────────┼───────────────┼────────────┤
│  etcd         │  etcd         │  etcd         │            │
│  API server   │  API server   │  API server   │            │
│  scheduler    │  scheduler    │  scheduler    │            │
│  workloads ✓  │  workloads ✓  │  workloads ✓  │ workloads ✓│
└───────────────┴───────────────┴───────────────┴────────────┘
```

**Fault tolerance:** Cluster stays healthy if 1 server fails. Loses quorum if 2+ servers fail.

## Day-to-Day Operations

### SSH Access

```bash
ssh k8sadmin@192.168.1.100  # or any node IP
```

### kubectl from Your Mac

Copy the kubeconfig from a server:

```bash
scp k8sadmin@192.168.1.100:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Update the server address
sed -i '' 's/127.0.0.1/192.168.1.100/' ~/.kube/config

kubectl get nodes
```

### Update Cluster Configuration (deploy-rs)

After initial setup, use deploy-rs for updates (like Ansible, but for NixOS):

```bash
# Deploy to ALL nodes at once
nix run .#deploy

# Deploy to a single node
nix run .#deploy .#k8s-server-1

# Deploy without checks (faster)
nix run .#deploy -- --skip-checks
```

**Features:**
- **Auto-rollback** - If deployment fails, automatically reverts
- **Magic rollback** - If you lose SSH connection, node reverts after 60s
- **Parallel deployment** - Updates all nodes simultaneously

Nodes also auto-update at 4 AM from your GitHub repo.

### Check Node Status

```bash
# System logs
ssh k8sadmin@192.168.1.100 "journalctl -u k3s -f"

# k3s status
ssh k8sadmin@192.168.1.100 "sudo systemctl status k3s"
```

## Troubleshooting

### Node won't join cluster

1. Check token matches: `cat /var/lib/k3s/token`
2. Verify network: `ping 192.168.1.100`
3. Check k3s logs: `journalctl -u k3s -e`

### Find network interface name

Boot the ISO and run:
```bash
ip link
```
Look for the ethernet interface (not `lo`). Update `network.interface` in `cluster-config.nix`.

### Reset a node

```bash
ssh k8sadmin@<IP>
sudo systemctl stop k3s
sudo rm -rf /var/lib/rancher/k3s
sudo reboot
```

Then redeploy with nixos-anywhere.

## File Structure

```
modules/kubernetes/
├── README.md            # This file
├── cluster-config.nix   # All cluster settings (IPs, token, SSH keys)
├── k8s-node.nix         # k3s service module
├── k8s-base.nix         # Base NixOS config for nodes
├── hardware.nix         # Mac mini Late 2014 kernel modules/firmware
├── disko.nix            # Disk layout (GPT, EFI, ext4) used by nixos-anywhere
├── static-ip.nix        # Static IP configuration
├── server-hardening.nix # Reliability & security settings
└── iso-k8s.nix          # Installer ISO configuration
```

## Security Notes

- `clusterToken` in `cluster-config.nix` is sensitive - don't commit to public repos
- Consider using [sops-nix](https://github.com/Mic92/sops-nix) for secrets management
- SSH password auth is disabled; only key-based auth works after install
