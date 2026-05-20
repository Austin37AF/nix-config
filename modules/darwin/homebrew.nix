{ ... }: {
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    brews = [
      "direnv"
      "gimme-aws-creds"
    ];
    casks = [
      # "balenaetcher"  # Currently broken in Homebrew - download from https://etcher.balena.io
      "docker-desktop"
      "google-chrome"
      "raycast"
      "slack"
      "windsurf"
    ];
  };
}
