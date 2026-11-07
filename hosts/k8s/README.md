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

# macOS: sops looks in ~/Library/Application Support/sops/age/ by default
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

# Create the encrypted secrets file
sops hosts/k8s/secrets/k8s.yaml
# In the editor, add:
#   k3s-token: "<output of: openssl rand -hex 32>"
# Save and exit - file is now encrypted
```

**Node host keys are pre-generated.** Each node's SSH host key lives in
`secrets/host-keys.yaml` (encrypted to your admin key only). Their age
equivalents are already recipients of `secrets/k8s.yaml` in `.sops.yaml`, and
`scripts/install-node.sh` installs the key, so nodes can decrypt the k3s token
on first boot. To add or rotate a node key:

```bash
ssh-keygen -t ed25519 -N "" -C root@<node> -f /tmp/<node>
sops hosts/k8s/secrets/host-keys.yaml                      # add "<node>: |" with the private key
ssh-to-age < /tmp/<node>.pub                     # add as a recipient in .sops.yaml
sops updatekeys hosts/k8s/secrets/k8s.yaml && rm /tmp/<node>*
```

### 3. Configure the Cluster

Edit `cluster-config.nix`:

- `sshPublicKeys` - Your SSH public key (`cat ~/.ssh/id_ed25519.pub`)
- `network.gateway` - Your router IP
- `network.interface` - NIC name (usually `enp0s3` or `eth0`)
- `nodes.*.ip` - Static IPs for each node

### 4. Get the Installer ISO

GitHub Actions builds the shared installer ISO (all NixOS hosts) on every push touching `installer/` and publishes it to
the rolling `nixos-installer` release (a Mac can't build x86_64-linux ISOs locally). The flash
script below downloads it automatically, or:

```bash
gh release download nixos-installer -R Austin37AF/nix-config -p nixos-installer.iso
```

Rebuild the ISO whenever `shared/ssh-keys.nix` changes (it bakes in your SSH key).

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

**Check the NIC first** (once, on any node), and set `network.interface` in `cluster-config.nix`:

```bash
ssh root@<IP> ip -br link
```

**Install in order** (server-1 must be first). The script shows the target's disks, asks you
to confirm, then **wipes** the disk from `cluster-config.nix` (`defaultDisk = "/dev/sda"`, or a
per-node `disk`), partitions it with `disko.nix` (512M EFI + ext4 root), installs the node's
SSH host key, and builds on the target (this Mac can't build x86_64-linux):

```bash
./scripts/install-node.sh k8s-server-1 <IP>
# Wait for server-1 to reboot and k3s to start (~2 min), then:
./scripts/install-node.sh k8s-server-2 <IP>
./scripts/install-node.sh k8s-server-3 <IP>
./scripts/install-node.sh k8s-agent-1  <IP>
```

If the internal ~500G disk isn't `/dev/sda` in the script's disk list, abort and set
`disk = "/dev/sdX";` on that node.

### 7. Verify Cluster

SSH into any server node:

```bash
ssh k8sadmin@10.17.17.100

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
│  10.17.17.100│  10.17.17.101│  10.17.17.102│ 10.17.17.103
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
ssh k8sadmin@10.17.17.100  # or any node IP
```

### kubectl from Your Mac

Copy the kubeconfig from a server:

```bash
scp k8sadmin@10.17.17.100:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Update the server address
sed -i '' 's/127.0.0.1/10.17.17.100/' ~/.kube/config

kubectl get nodes
```

### Update Cluster Configuration (deploy-rs)

After initial setup, updates are pushed over SSH with deploy-rs (like Ansible, but for NixOS).
The easy way is heimdall:

```bash
nix flake update nixpkgs             # optional: pick up new packages/kernel
heimdall cluster update --dry-run    # build on the nodes, show what would change
heimdall cluster update              # deploy to all nodes (or name specific nodes)
heimdall cluster update --reboot     # deploy, then rolling reboot of nodes with a new kernel
heimdall cluster reboot-needed       # check which nodes are on an old kernel
```

Or deploy-rs directly:

```bash
cd hosts/k8s
nix run .#deploy                       # all nodes
nix run .#deploy -- .#k8s-server-1     # one node
nix run .#deploy -- --skip-checks      # skip flake checks
```

**Features:**
- **Auto-rollback** - If deployment fails, automatically reverts
- **Magic rollback** - If you lose SSH connection, node reverts after 60s
- **Rolling reboots** (heimdall `--reboot`) - drain, reboot, wait for Ready, uncordon, one node at a time

deploy-rs builds on the nodes themselves (`remoteBuild`). There's no automatic upgrade:
to update, run `nix flake update` in `hosts/k8s` (or bump single inputs), then `nix run .#deploy`. This only moves the cluster; other machines have their own lock files.

### Check Node Status

```bash
# System logs
ssh k8sadmin@10.17.17.100 "journalctl -u k3s -f"

# k3s status
ssh k8sadmin@10.17.17.100 "sudo systemctl status k3s"
```

## Troubleshooting

### Node won't join cluster

1. Check token matches: `cat /var/lib/k3s/token`
2. Verify network: `ping 10.17.17.100`
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
hosts/k8s/
├── flake.nix            # Node configs, deploy-rs, checks (own flake.lock)
├── README.md            # This file
├── cluster-config.nix   # All cluster settings (IPs, disk; SSH keys from shared/ssh-keys.nix)
├── k8s-node.nix         # k3s service module
├── k8s-base.nix         # Base NixOS config for nodes
├── hardware.nix         # Mac mini Late 2014 kernel modules/firmware
├── static-ip.nix        # Static IP configuration
├── server-hardening.nix # Reliability & security settings
├── install-hook.sh      # install-host hook: seeds the node's SSH host key from sops
└── secrets/             # sops: k8s.yaml (k3s token), host-keys.yaml (node host keys)

Shared: ../../shared/disko-single-disk.nix (disk layout), ../../installer/ (ISO)
```

## Security Notes

- `clusterToken` in `cluster-config.nix` is sensitive - don't commit to public repos
- Consider using [sops-nix](https://github.com/Mic92/sops-nix) for secrets management
- SSH password auth is disabled; only key-based auth works after install
