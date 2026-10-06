{
  description = "Austin's Nix configurations for Darwin and NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    
    # For building custom ISOs
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
    
    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    
    # SSH deployment (like Ansible for NixOS)
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative disk partitioning for K8s nodes (used by nixos-anywhere)
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative tap management (Darwin only)
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    # Homelab CLI (cluster ops, `heimdall ai` for the local LLM server)
    heimdall.url = "git+ssh://git@github.com/Austin37AF/heimdall";
    heimdall.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, home-manager, homebrew-core, homebrew-cask, nixos-generators, sops-nix, deploy-rs, heimdall, disko }:
  let
    # Darwin pkgs
    darwinPkgs = import nixpkgs {
      system = "aarch64-darwin";
      config.allowUnfree = true;
    };
    # NixOS pkgs
    nixosPkgs = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
  in
  {
    # Dev shell for projects without their own Devbox
    devShells.aarch64-darwin.default = import ./modules/devshell.nix { pkgs = darwinPkgs; };
    devShells.x86_64-linux.default = import ./modules/devshell.nix { pkgs = nixosPkgs; };

    # ============================================
    # Darwin Configuration (macOS)
    # ============================================
    # 
    # Configurations:
    #   austin-m5-pro       - Work machine (with Zscaler, gimme-aws-creds)
    #   austin-m5-pro-home  - Personal mode (no work tools)
    #
    # Usage:
    #   rebuild                                              # Work mode (default)
    #   sudo darwin-rebuild switch --flake ~/nix#austin-m5-pro-home  # Personal mode
    #
    darwinConfigurations = let
      # Base modules shared by all Darwin configs
      baseModules = [
        ./modules/darwin/default.nix
        ./modules/darwin/homebrew.nix
        ./modules/darwin/zsh.nix
        ./modules/local-ai/darwin.nix
        
        { system.configurationRevision = self.rev or self.dirtyRev or null; }
        { environment.systemPackages = [ heimdall.packages.aarch64-darwin.default ]; }
        
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            user = "austin.mills";
            autoMigrate = true;
            enableRosetta = true;
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
            };
            mutableTaps = true;
          };
        }
        
        ({ config, lib, ... }: {
          homebrew.taps = lib.mkAfter (builtins.attrNames config.nix-homebrew.taps);
        })
        
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users."austin.mills" = { ... }: {
            imports = [
              ./modules/common/home.nix
              ./modules/darwin/home.nix
              ./modules/local-ai/home.nix
            ];
          };
        }
      ];
      
      # Work-specific modules
      workModules = [ ./modules/hosts/work ];
    in {
      # Work machine (default)
      "austin-m5-pro" = nix-darwin.lib.darwinSystem {
        modules = baseModules ++ workModules;
      };
      
      # Personal mode (no Zscaler, gimme-aws-creds, etc.)
      "austin-m5-pro-home" = nix-darwin.lib.darwinSystem {
        modules = baseModules;
      };
    };

    # ============================================
    # NixOS Configurations
    # ============================================
    nixosConfigurations = let
      # Kubernetes cluster config
      clusterCfg = import ./modules/kubernetes/cluster-config.nix;
      
      mkK8sNode = name: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./modules/kubernetes/k8s-base.nix
          ./modules/kubernetes/hardware.nix
          disko.nixosModules.disko
          (import ./modules/kubernetes/disko.nix {
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
    in {
      # ============================================
      # Kubernetes Cluster Nodes (Mac Minis)
      # ============================================
      # 
      # HA Setup: 3 servers (etcd quorum) + 1 dedicated worker
      # Configuration is centralized in: modules/kubernetes/cluster-config.nix
      #
      # Install order:
      #   1. k8s-server-1 (initializes cluster)
      #   2. k8s-server-2, k8s-server-3 (join as servers)
      #   3. k8s-agent-1 (join as worker)
      
      "k8s-server-1" = mkK8sNode "k8s-server-1";
      "k8s-server-2" = mkK8sNode "k8s-server-2";
      "k8s-server-3" = mkK8sNode "k8s-server-3";
      "k8s-agent-1" = mkK8sNode "k8s-agent-1";
    };

    # ============================================
    # K8s Installer ISO
    # ============================================
    # 
    # Build: nix build .#k8s-installer-iso
    # 
    # Usage with nixos-anywhere (recommended):
    #   1. Boot Mac Mini from ISO (gets DHCP IP)
    #   2. Find IP: check router or run `ip addr` on the Mac Mini
    #   3. Deploy: nix run github:nix-community/nixos-anywhere -- \
    #        --flake .#k8s-server-1 root@<IP>
    #
    # Install order: server-1 first, then server-2/3, then agent-1
    
    packages.x86_64-linux.k8s-installer-iso = nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      format = "iso";
      modules = [ ./modules/kubernetes/iso-k8s.nix ];
    };

    # ============================================
    # Deploy-rs Configuration
    # ============================================
    # 
    # Deploy all K8s nodes:  nix run .#deploy
    # Deploy one node:       nix run .#deploy .#k8s-server-1
    # Deploy with checks:    nix run .#deploy -- --skip-checks
    
    deploy = {
      sshUser = "k8sadmin";
      user = "root";
      sshOpts = [ "-o" "StrictHostKeyChecking=no" ];
      fastConnection = true;
      autoRollback = true;
      magicRollback = true;
      
      nodes = let
        clusterCfg = import ./modules/kubernetes/cluster-config.nix;
        mkDeployNode = name: {
          hostname = clusterCfg.nodes.${name}.ip;
          profiles.system = {
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.${name};
          };
        };
      in {
        k8s-server-1 = mkDeployNode "k8s-server-1";
        k8s-server-2 = mkDeployNode "k8s-server-2";
        k8s-server-3 = mkDeployNode "k8s-server-3";
        k8s-agent-1 = mkDeployNode "k8s-agent-1";
      };
    };

    # Deploy-rs checks
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
