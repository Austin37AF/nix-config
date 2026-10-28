{ pkgs }: {
  # CLI tools - shared between system and dev shell
  cli = [
    pkgs.awscli2
    pkgs.kubectl
    (pkgs.wrapHelm pkgs.kubernetes-helm { plugins = [ pkgs.kubernetes-helmPlugins.helm-unittest ]; })
    pkgs.k9s
    pkgs.gh
    pkgs.pre-commit
    (pkgs.google-cloud-sdk.withExtraComponents [
      pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
    ])
    pkgs.jq
    pkgs.yq
    pkgs.nixd  # Nix language server for IDE support
    pkgs.devbox
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
    pkgs.kyverno
    pkgs.kubeconform
    # Native arm64 nodes: env.nix sets DOCKER_DEFAULT_PLATFORM=linux/amd64 for
    # image builds, which would run kind nodes under emulation (containerd fails)
    (pkgs.writeShellScriptBin "kind" ''
      unset DOCKER_DEFAULT_PLATFORM
      exec ${pkgs.kind}/bin/kind "$@"
    '')
  ];
  
  # Fonts
  fonts = [
    pkgs.nerd-fonts.jetbrains-mono
  ];
}
