# Work machine configuration (BRT/Deere)
# Import this module for work machines only
#
# Includes:
# - Zscaler SSL certificate configuration
# - gimme-aws-creds for Okta AWS auth
# - valhalla shell completions
# - Devin CLI AGENTS.md work-network addendum
{ ... }: {
  imports = [
    ./zscaler.nix
    ./homebrew.nix
    ./devin
  ];
}
