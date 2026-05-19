{ ... }: {
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    brews = [
      "direnv"
    ];
    casks = [
      "docker-desktop"
      "google-chrome"
      "raycast"
      "slack"
      "windsurf"
    ];
  };
}
