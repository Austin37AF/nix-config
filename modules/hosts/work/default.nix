# Work machine configuration (BRT/Deere)
# Import this module for work machines only
#
# Includes:
# - Zscaler SSL certificate configuration
# - gimme-aws-creds for Okta AWS auth
# - valhalla shell completions
{ ... }: {
  imports = [
    ./zscaler.nix
    ./homebrew.nix
  ];
}
