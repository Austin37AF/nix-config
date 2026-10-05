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
    # pkgs.direnv  # TODO: re-enable when cache is accessible (builds from source hang on tests)
    pkgs.icloudpd  # iCloud Photos Downloader
    pkgs.prettier
  ];
  
  # Dev-only tools
  dev = [
    pkgs.go
    (pkgs.python3.withPackages (ps: [ ps.pip ]))
    pkgs.opentofu
    pkgs.powerline-go
    pkgs.act
  ];
  
  # Fonts
  fonts = [
    pkgs.nerd-fonts.jetbrains-mono
  ];
}
