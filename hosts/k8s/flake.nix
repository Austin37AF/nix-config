{
  description = "k8s: K3s cluster nodes (Mac Minis), deployed with deploy-rs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # SSH deployment
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative disk partitioning (used by the installer / nixos-anywhere)
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, sops-nix, deploy-rs, disko, ... }:
  let
    clusterCfg = import ./cluster-config.nix;

    darwinPkgs = import nixpkgs { system = "aarch64-darwin"; };
    nixosPkgs = import nixpkgs { system = "x86_64-linux"; };
    # deploy-rs lib with the nixpkgs deploy-rs binary (cache.nixos.org) instead of
    # compiling the flake's own build
    deployPkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [
        deploy-rs.overlays.default
        (final: prev: { deploy-rs = { inherit (nixosPkgs) deploy-rs; lib = prev.deploy-rs.lib; }; })
      ];
    };

    mkK8sNode = name: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./k8s-base.nix
        ./hardware.nix
        disko.nixosModules.disko
        (import ../../shared/disko-single-disk.nix {
          device = clusterCfg.nodes.${name}.disk or clusterCfg.defaultDisk;
        })
        sops-nix.nixosModules.sops
        ({ lib, config, ... }:
          let
            nodeCfg = clusterCfg.nodes.${name};
          in {
            networking.hostName = name;

            # Sops secrets configuration
            sops = {
              defaultSopsFile = ./secrets/k8s.yaml;
              age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
              secrets.k3s-token = {};
            };

            # Static IP configuration
            k8s-static-ip = {
              enable = true;
              address = nodeCfg.ip;
              gateway = clusterCfg.network.gateway;
              prefixLength = clusterCfg.network.prefixLength;
              nameservers = clusterCfg.network.nameservers;
              interface = clusterCfg.network.interface;
            };

            # SSH keys from cluster config
            users.users.k8sadmin.openssh.authorizedKeys.keys = clusterCfg.sshPublicKeys;

            # K3s configuration
            k8s-node = {
              enable = true;
              role = nodeCfg.role;
              clusterInit = nodeCfg.clusterInit;
              serverAddr = lib.mkIf (!nodeCfg.clusterInit) clusterCfg.k3s.serverAddr;
              extraFlags = lib.mkIf nodeCfg.clusterInit
                (map (san: "--tls-san=${san}") clusterCfg.k3s.tlsSans);
              tokenFile = config.sops.secrets.k3s-token.path;
            };
          })
      ];
    };

    nodeNames = builtins.attrNames clusterCfg.nodes;
  in {
    # HA Setup: 3 servers (etcd quorum) + 1 dedicated worker, defined in ./cluster-config.nix
    # Install order: k8s-server-1 (initializes cluster), k8s-server-2/3, then k8s-agent-1
    nixosConfigurations = nixpkgs.lib.genAttrs nodeNames mkK8sNode;

    # Deploy all nodes:  nix run .#deploy            (from this directory, or: heimdall cluster update)
    # Deploy one node:   nix run .#deploy -- .#k8s-server-1
    # Skip checks:       nix run .#deploy -- --skip-checks
    apps.aarch64-darwin.deploy = { type = "app"; program = "${darwinPkgs.deploy-rs}/bin/deploy"; };
    apps.x86_64-linux.deploy = { type = "app"; program = "${nixosPkgs.deploy-rs}/bin/deploy"; };

    deploy = {
      sshUser = "k8sadmin";
      user = "root";
      sshOpts = [ "-o" "StrictHostKeyChecking=no" ];
      fastConnection = true;
      remoteBuild = true;  # Build on the x86_64 nodes; the Mac can't build x86_64-linux
      autoRollback = true;
      magicRollback = true;

      nodes = nixpkgs.lib.genAttrs nodeNames (name: {
        hostname = clusterCfg.nodes.${name}.ip;
        profiles.system.path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.${name};
      });
    };

    # Deploy-rs checks (nodes are x86_64-linux; other systems would try to build their closures)
    checks.x86_64-linux = deployPkgs.deploy-rs.lib.deployChecks self.deploy;
  };
}
