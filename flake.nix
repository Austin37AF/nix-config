{
  # Machines are standalone flakes in hosts/<name>, each with its own flake.lock.
  # This root flake only holds what isn't tied to a machine: the dev shell and the installer ISO.
  description = "Austin's Nix configs: dev shell and installer ISO (machines live in hosts/)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs, ... }:
  let
    pkgsFor = system: import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in
  {
    # Dev shell for projects without their own Devbox (`dev` alias, direnv)
    devShells.aarch64-darwin.default = import ./shared/devshell.nix { pkgs = pkgsFor "aarch64-darwin"; };
    devShells.x86_64-linux.default = import ./shared/devshell.nix { pkgs = pkgsFor "x86_64-linux"; };

    # Installer ISO for every NixOS host: boot it and run `install-host` (see installer/install-host.sh)
    # Build: nix build .#installer-iso
    nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./installer/iso.nix ];
    };
    packages.x86_64-linux.installer-iso = self.nixosConfigurations.installer.config.system.build.isoImage;
  };
}
