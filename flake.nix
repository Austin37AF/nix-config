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

    # Declarative tap management (Darwin only)
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, home-manager, homebrew-core, homebrew-cask, nix-vscode-extensions, nixos-generators, sops-nix, deploy-rs }:
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
    darwinConfigurations."austin-m5-pro" = nix-darwin.lib.darwinSystem {
      modules = [
        # Core modules
        ./modules/darwin/default.nix
        ./modules/darwin/homebrew.nix
        ./modules/darwin/zsh.nix
        
        # Work machine config (Zscaler, gimme-aws-creds, etc.)
        ./modules/hosts/work
        
        # Set git revision
        { system.configurationRevision = self.rev or self.dirtyRev or null; }
        
        # nix-homebrew
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
        
        # Align homebrew taps config with nix-homebrew + additional taps from homebrew.nix
        ({ config, lib, ... }: {
          homebrew.taps = lib.mkAfter (builtins.attrNames config.nix-homebrew.taps);
        })
        
        # Home Manager
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users."austin.mills" = { ... }: {
            imports = [
              ./modules/common/home.nix
              ./modules/darwin/home.nix
            ];
          };
        }
      ];
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
          sops-nix.nixosModules.sops
          ({ lib, config, ... }: 
            let 
              nodeCfg = clusterCfg.nodes.${name};
            in {
              networking.hostName = name;
              
              # Sops secrets configuration
              sops = {
                defaultSopsFile = ../../secrets/k8s.yaml;
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
      # Linux laptop
      "nixos-laptop" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./modules/nixos/hardware-configuration.nix
          ./modules/nixos/default.nix
          ./modules/nixos/zsh.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.austinm = { ... }: {
              imports = [ ./modules/common/home.nix ];
              programs.vscode.extensions = [
                nix-vscode-extensions.extensions.x86_64-linux.vscode-marketplace.google.geminicodeassist
              ];
            };
          }
        ];
      };
      
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
