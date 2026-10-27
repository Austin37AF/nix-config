# Work-only Devin CLI additions: append the Zscaler notes to the managed
# ~/.config/devin/AGENTS.md (home.file.text is types.lines, so this is
# concatenated after the base text from modules/darwin/devin).
{ lib, ... }: {
  home-manager.users."austin.mills".home.file.".config/devin/AGENTS.md".text = lib.mkAfter ''

    ## Work network (Zscaler)
    - TLS is intercepted by Zscaler. The trusted CA bundle (public roots + Zscaler root) is /etc/ssl/certs/ca-certificates.crt, linked at ~/certs/bundle.crt; SSL_CERT_FILE, REQUESTS_CA_BUNDLE, NODE_EXTRA_CA_CERTS and NIX_SSL_CERT_FILE point to it.
    - On certificate errors, point the tool at that bundle. Never disable TLS verification (`curl -k`, `verify=False`, `NODE_TLS_REJECT_UNAUTHORIZED=0`, `http.sslVerify=false`).
  '';
}
