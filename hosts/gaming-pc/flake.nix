{
  description = "gaming-pc: NixOS desktop (KDE Plasma 6, Steam, WoW Forever)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative disk partitioning (used by the installer)
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Homelab CLI
    heimdall.url = "git+ssh://git@github.com/Austin37AF/heimdall";
    heimdall.inputs.nixpkgs.follows = "nixpkgs";

    # Battle.net via umu-launcher, wrapped by ./wow-forever
    battlenet-umu.url = "github:jacobjdowning/battlenet-umu";
    battlenet-umu.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Install: boot the installer ISO and run `install-host`, or ../../scripts/install-gaming-pc.sh
  # Rebuild on the PC: `rebuild` (builds as the user, activates with sudo)
  outputs = { self, nixpkgs, home-manager, disko, heimdall, battlenet-umu, ... }: {
    nixosConfigurations."gaming-pc" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./default.nix
        disko.nixosModules.disko
        { system.configurationRevision = self.rev or self.dirtyRev or null; }
        { environment.systemPackages = [ heimdall.packages.x86_64-linux.default ]; }
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.austin = {
            imports = [
              ../../shared/home.nix
              ./home.nix
              battlenet-umu.homeModules.default
              ./wow-forever
              ./jagex-launcher
            ];
          };
        }
      ];
    };
  };
}
