{
  description = "WoW Forever on Linux: Battle.net via umu-launcher + declarative addons (wraps battlenet-umu)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    battlenet-umu.url = "github:jacobjdowning/battlenet-umu";
    battlenet-umu.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { battlenet-umu, ... }: {
    homeModules.default = {
      imports = [
        battlenet-umu.homeModules.default
        ./module.nix
      ];
    };
  };
}
