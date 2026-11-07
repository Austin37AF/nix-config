{
  description = "wsl: NixOS-WSL on the Windows PC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    # Homelab CLI
    heimdall.url = "git+ssh://git@github.com/Austin37AF/heimdall";
    heimdall.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Rebuild inside WSL: `rebuild` (builds as the user so the private heimdall
  # input is fetched with the user's SSH key, activates with sudo).
  outputs = { self, nixpkgs, home-manager, nixos-wsl, heimdall, ... }: {
    nixosConfigurations."wsl" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixos-wsl.nixosModules.default
        ./default.nix
        { system.configurationRevision = self.rev or self.dirtyRev or null; }
        { environment.systemPackages = [ heimdall.packages.x86_64-linux.default ]; }
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.nixos = {
            imports = [ ../../shared/home.nix ./home.nix ];
          };
        }
      ];
    };
  };
}
