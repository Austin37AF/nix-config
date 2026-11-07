# Darwin-specific home-manager settings
{ machine, ... }:

{
  imports = [ ../../shared/devin ];

  # SSH config (this file replaces a hand-written ~/.ssh/config; ad-hoc hosts go in ~/.ssh/config.local)
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "config.local" ];
    settings."github.com" = {
      IdentityFile = "~/.ssh/${machine.sshKey}";
      IdentitiesOnly = "yes";
      AddKeysToAgent = "yes";
      UseKeychain = "yes";
    };
  };
}
