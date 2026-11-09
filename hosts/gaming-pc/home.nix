# Gaming PC Home Manager settings
{ lib, pkgs, ... }:
let
  # Bambu Studio's 3D view renders blank with the NVIDIA EGL driver (GTX 1060, 580 legacy).
  # Run its OpenGL through Mesa's Zink instead, which still uses the GPU via NVIDIA's Vulkan driver.
  # Wraps the existing package, so it doesn't trigger a rebuild from source.
  bambu-studio = pkgs.symlinkJoin {
    name = "bambu-studio-zink";
    paths = [ pkgs.bambu-studio ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/bambu-studio \
        --set __GLX_VENDOR_LIBRARY_NAME mesa \
        --set __EGL_VENDOR_LIBRARY_FILENAMES /run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json \
        --set MESA_LOADER_DRIVER_OVERRIDE zink \
        --set GALLIUM_DRIVER zink
    '';
  };
in
{
  imports = [ ../../shared/devin ];

  home.packages = with pkgs; [
    devin-desktop
    devin-cli
    discord
    google-chrome
    bambu-studio # the Zink wrapper above (let bindings shadow `with pkgs`)
  ];

  # Battle.net + WoW Forever launchers and declarative addons (./wow-forever)
  programs.wow-forever = {
    enable = true;
    prefix = "/games/battlenet-umu/prefix"; # games NVMe, not the OS SSD
    # Battle.net installed WoW on its S: drive (/games), outside the prefix
    installDir = "/games/World of Warcraft/_forever_";
    # Pinned CurseForge files (Forever Guide, Details! damage meter). Bump them with
    # `wow-addons-update`, then commit and rebuild; add one by its CurseForge Project ID there.
    curseforgeAddons = lib.importJSON ./wow-forever/curseforge.json;
  };

  # GitHub key for this machine (~/.ssh/gaming-pc); ad-hoc hosts go in ~/.ssh/config.local
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "config.local" ];
    settings."github.com" = {
      IdentityFile = "~/.ssh/gaming-pc";
      IdentitiesOnly = "yes";
      AddKeysToAgent = "yes";
    };
  };

  # direnv loads the dev shell for repos under ~/repos, as on WSL (see hosts/wsl/home.nix)
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = false; # shared/zsh.nix already runs `direnv hook zsh`
  };

  home.file = {
    ".config/direnv/direnv.toml".text = ''
      [global]
      hide_env_diff = true

      [whitelist]
      exact = ["/home/austin/repos/.envrc", "/home/austin/homelab/nix/.envrc"]
    '';

    "repos/.envrc".text = ''
      use flake /home/austin/homelab/nix
      watch_file /home/austin/homelab/nix/flake.lock /home/austin/homelab/nix/shared/devshell.nix /home/austin/homelab/nix/shared/packages.nix /home/austin/homelab/nix/shared/env.nix
    '';
  };
}
