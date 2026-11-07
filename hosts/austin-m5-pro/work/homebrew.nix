# Work-specific Homebrew packages (BRT/Deere tools)
{ ... }: {
  homebrew.brews = [
    "gimme-aws-creds"  # Deere/BRT Okta AWS auth
  ];
}
