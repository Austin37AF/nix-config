{ ... }: {
  homebrew = {
    enable = true;
    enableZshIntegration = true;  # brew shellenv (replaces the old hand-written ~/.zprofile)
    onActivation.cleanup = "zap";
    taps = [];
    brews = [
      "direnv"
    ];
    casks = [
      # "balenaetcher"  # Currently broken in Homebrew - download from https://etcher.balena.io
      "docker-desktop"
      "google-chrome"
      "raycast"
      "slack"
      "stats"
      "devin-desktop"  # formerly "windsurf"
    ];
  };
}
