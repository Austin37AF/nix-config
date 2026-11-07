# Gaming PC Home Manager settings
{ ... }:
{
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

  # direnv loads the dev shell for repos under ~/repos, as on WSL (see modules/hosts/wsl/home.nix)
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = false; # common/zsh.nix already runs `direnv hook zsh`
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
      watch_file /home/austin/homelab/nix/flake.lock /home/austin/homelab/nix/modules/devshell.nix /home/austin/homelab/nix/modules/common/packages.nix /home/austin/homelab/nix/modules/common/env.nix
    '';
  };
}
