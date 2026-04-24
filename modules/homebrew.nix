{ ... }: {
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
    
    brews = [
      "awscli"
      "direnv"
      "gh"
      "gimme-aws-creds"
      "k9s"
      "pre-commit"
      "mas"
    ];
    
    casks = [
      "docker-desktop"
      "gcloud-cli"
      "google-drive"
      "raycast"
      # "google-chrome"
      # "slack"
    ];
  };
}
