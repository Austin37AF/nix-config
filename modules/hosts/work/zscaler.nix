# Zscaler certificate configuration for BRT work machines
# Import this module only on machines behind Zscaler (e.g., work laptop)
#
# Usage in flake.nix darwin/nixos config:
#   imports = [ ./modules/common/zscaler.nix ];
#
# Or conditionally:
#   imports = lib.optionals isWorkMachine [ ./modules/common/zscaler.nix ];
#
# The CA bundle at /etc/ssl/certs/ca-certificates.crt is Nix-generated:
# nixpkgs cacert roots plus the Zscaler root (./zscaler-root.crt) via
# security.pki.certificateFiles, so it tracks nixpkgs updates automatically.
{ config, lib, pkgs, ... }:

let
  certBundle = "/etc/ssl/certs/ca-certificates.crt";
in
{
  security.pki.certificateFiles = [ ./zscaler-root.crt ];

  # ~/certs/bundle.crt is referenced by ~/.gitconfig (http.sslCAInfo) and
  # gcloud (custom_ca_certs_file); manage it as a link to the Nix bundle.
  # The pre-existing hand-made file is backed up via
  # home-manager.backupFileExtension = "hm-backup".
  home-manager.users."austin.mills".home.file."certs/bundle.crt".source =
    config.environment.etc."ssl/certs/ca-certificates.crt".source;

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
