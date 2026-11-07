# NixOS-WSL on the Windows PC: shared CLI tools, zsh + powerline prompt, Home Manager (git, prompt scripts)
{ pkgs, lib, ... }:
let
  commonPackages = import ../../shared/packages.nix { inherit pkgs; };
in
{
  imports = [ ../../shared/zsh.nix ];

  wsl.enable = true;
  wsl.defaultUser = "nixos";

  # Applied by WSL on the next `wsl --shutdown`
  networking.hostName = "wsl";
  time.timeZone = "America/Denver";

  # Prebuilt binaries (editor remote servers, Devin CLI, etc.)
  programs.nix-ld.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = commonPackages.cli ++ (with pkgs; [ vim wget git ]);

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # The repo is cloned at ~/repos/nix-config; the shared rebuild/dev aliases expect ~/homelab/nix
  systemd.tmpfiles.rules = [
    "d /home/nixos/homelab 0755 nixos users -"
    "L /home/nixos/homelab/nix - - - - /home/nixos/repos/nix-config"
  ];

  # Build as the user (private heimdall input over the user's SSH key), activate with sudo
  programs.zsh.interactiveShellInit = lib.mkAfter ''
    alias rebuild="nixos-rebuild switch --flake ~/homelab/nix/hosts/wsl#wsl --sudo"
  '';

  system.stateVersion = "26.05";
}
