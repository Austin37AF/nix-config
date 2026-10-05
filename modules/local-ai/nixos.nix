# Local AI tooling for NixOS desktops (LM Studio + nvtop)
# Zed is installed via home-manager (see ./home.nix)
{ pkgs, ... }: {
  environment.systemPackages = [
    pkgs.lmstudio
    pkgs.nvtopPackages.full
  ];
}
