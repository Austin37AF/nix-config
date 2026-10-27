# eMudhra compromise (Oct 2026): remove the roots the compromised intermediates
# chain to from /etc/ssl/cert.pem, per https://support.apple.com/en-us/149555.
#
# macOS built-in curl, git, python3, ruby, perl and openssl trust that file
# without checking Apple's block list or revocation. Runs on every rebuild,
# so it re-applies if a macOS update restores the file, and is a no-op once
# Apple ships a fixed cert.pem. Apple's original is kept at /etc/ssl/cert.pem.orig.
{ pkgs, lib, ... }:
let
  distrustedRoots = [
    "=== /C=IN/OU=emSign PKI/O=eMudhra Technologies Limited/CN=emSign ECC Root CA - G3"
    "=== /C=GB/ST=Greater Manchester/L=Salford/O=Comodo CA Limited/CN=AAA Certificate Services"
  ];
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "pruning distrusted roots from /etc/ssl/cert.pem..." >&2
    (
      set -euo pipefail
      f=/etc/ssl/cert.pem
      present=()
      for s in ${lib.escapeShellArgs distrustedRoots}; do
        if grep -qxF "$s" "$f"; then present+=("$s"); fi
      done
      [ ''${#present[@]} -eq 0 ] && exit 0

      # A match means this is Apple's file (original or restored by an update)
      cp -p "$f" "$f.orig"
      t=$(mktemp)
      trap 'rm -f "$t" "$t.new"' EXIT
      cp "$f" "$t"
      for s in "''${present[@]}"; do
        /usr/bin/awk -v s="$s" '/^(===|###) /{skip=0} $0==s{skip=1} !skip' "$t" > "$t.new"
        mv "$t.new" "$t"
      done

      before=$(grep -c 'BEGIN CERTIFICATE' "$f")
      after=$(grep -c 'BEGIN CERTIFICATE' "$t")
      if [ "$after" -ne $((before - ''${#present[@]})) ]; then
        echo "cert.pem: unexpected cert count ($before -> $after), leaving file unchanged" >&2
        exit 1
      fi
      ${pkgs.openssl}/bin/openssl crl2pkcs7 -nocrl -certfile "$t" > /dev/null

      install -m 0644 -o root -g wheel "$t" "$f"
      echo "removed ''${#present[@]} root(s) from $f (backup: $f.orig)" >&2
    ) || echo "warning: could not prune /etc/ssl/cert.pem; it was left unchanged" >&2
  '';
}
