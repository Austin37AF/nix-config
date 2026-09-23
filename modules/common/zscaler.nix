# Zscaler certificate configuration for BRT work machines
# Import this module only on machines behind Zscaler (e.g., work laptop)
#
# Usage in flake.nix darwin/nixos config:
#   imports = [ ./modules/common/zscaler.nix ];
#
# Or conditionally:
#   imports = lib.optionals isWorkMachine [ ./modules/common/zscaler.nix ];
{ config, lib, pkgs, ... }:

let
  certBundle = "/Users/austin.mills/certs/bundle.crt";
  # For NixOS, use a different path
  # certBundle = if pkgs.stdenv.isDarwin then "/Users/austin.mills/certs/bundle.crt" else "/home/austinm/certs/bundle.crt";
in
{
  # Nix daemon SSL cert (for nix develop, nix build, etc.)
  nix.settings.ssl-cert-file = certBundle;

  # Shell environment variables for various tools
  # These are set via programs.zsh.interactiveShellInit or similar
  environment.variables = {
    # Node.js
    NODE_EXTRA_CA_CERTS = certBundle;
    # Python requests library
    REQUESTS_CA_BUNDLE = certBundle;
    # Nix CLI (redundant with nix.settings but ensures subprocesses inherit it)
    NIX_SSL_CERT_FILE = certBundle;
  };
}
