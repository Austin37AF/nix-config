{ pkgs }: {
  # CLI tools - shared between system and dev shell
  cli = [
    pkgs.awscli2
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.k9s
    pkgs.gh
    pkgs.pre-commit
    (pkgs.google-cloud-sdk.withExtraComponents [
      pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
    ])
    pkgs.jq
    pkgs.yq
    pkgs.nixd  # Nix language server for IDE support
  ];
  
  # Dev-only tools
  dev = [
    pkgs.go
    pkgs.python3
    pkgs.opentofu
    pkgs.powerline-go
  ];
  
  # Fonts
  fonts = [
    pkgs.nerd-fonts.jetbrains-mono
  ];
  
  # GUI apps (system only)
  gui = [
    pkgs.vim
    pkgs.mkalias
    pkgs.obsidian
    pkgs.alt-tab-macos
    pkgs.hidden-bar
    pkgs.rectangle
    pkgs.stats
    pkgs.the-unarchiver
  ];
}
