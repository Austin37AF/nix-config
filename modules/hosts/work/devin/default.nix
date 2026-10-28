# Work-only Devin CLI additions:
# - append the Zscaler + Kubernetes notes to the managed
#   ~/.config/devin/AGENTS.md (home.file.text is types.lines, so this is
#   concatenated after the base text from modules/darwin/devin)
# - out-of-store symlinks for per-repo AGENTS.local.md files and Devin
#   skills. The links point at this live checkout (not a /nix/store copy),
#   so editing the files takes effect without a rebuild; AGENTS.local.md is
#   kept out of the work repos' git via the global git ignore
#   (programs.git.ignores in modules/common/home.nix).
{ config, lib, ... }:

let
  hm = config.home-manager.users."austin.mills";
  base = "/Users/austin.mills/homelab/nix/modules/hosts/work/devin";

  # "home-relative target" -> "path under ${base}"
  outOfStoreLinks = {
    "brt-projects/brt-prod-infrastructure/AGENTS.local.md" = "repos/brt-prod-infrastructure.md";
    "sparkai-projects/gitops/AGENTS.local.md" = "repos/sparkai-gitops.md";
    "sparkai-projects/infrastructure/AGENTS.local.md" = "repos/sparkai-infrastructure.md";
    ".config/devin/skills/kyverno-test" = "skills/kyverno-test";
    ".config/devin/skills/chart-check" = "skills/chart-check";
    ".config/devin/skills/go-bump-release" = "skills/go-bump-release";
    ".config/devin/skills/ci-local" = "skills/ci-local";
  };
in
{
  home-manager.users."austin.mills".home.file =
    lib.mapAttrs' (target: src:
      lib.nameValuePair target {
        source = hm.lib.file.mkOutOfStoreSymlink "${base}/${src}";
      })
      outOfStoreLinks
    // {
      ".config/devin/AGENTS.md".text = lib.mkAfter ''

    ## Work network (Zscaler)
    - TLS is intercepted by Zscaler. The trusted CA bundle (public roots + Zscaler root) is /etc/ssl/certs/ca-certificates.crt, linked at ~/certs/bundle.crt; SSL_CERT_FILE, REQUESTS_CA_BUNDLE, NODE_EXTRA_CA_CERTS and NIX_SSL_CERT_FILE point to it.
    - On certificate errors, point the tool at that bundle. Never disable TLS verification (`curl -k`, `verify=False`, `NODE_TLS_REJECT_UNAUTHORIZED=0`, `http.sslVerify=false`).

    ## Kubernetes and cloud
    - The kubeconfig includes prod contexts (`brtplat-prod`, `gke_sparkai-prod_us-central1_prod-cluster`, ...). Always pass `--context` to kubectl and `--kube-context` to helm; never rely on or change the current context.
    - Only `docker-desktop` (or a local `kind-*` cluster) may be modified. On any other cluster use read-only commands (get, describe, logs, diff) and propose changes as PR edits.
    - Terraform/OpenTofu changes go through PRs and Atlantis: never run `apply` or `destroy` locally.
    - For local tests use the `kyverno-test` and `chart-check` skills, and clean up everything you create.
    - For any other throwaway cluster use kind rather than changing `docker-desktop`: `kind create cluster --name <task> --image kindest/node:<version> --config ~/.config/kind/cluster.yaml --kubeconfig /tmp/kind-<task>.kubeconfig` (the config mounts the Zscaler CA bundle; the separate kubeconfig keeps ~/.kube/config and its current context untouched). Pass `--kubeconfig /tmp/kind-<task>.kubeconfig --context kind-<task>` to kubectl/helm, and `kind delete cluster --name <task> --kubeconfig /tmp/kind-<task>.kubeconfig` when done.
    - Images built locally for linux/amd64 (the default here) won't run on the arm64 kind nodes; build with `--platform linux/arm64` before `kind load docker-image`.

    ## Work dev shell
    - Under ~/brt-projects and ~/sparkai-projects, direnv loads the homelab dev shell (go, tofu, helm with helm-unittest, kyverno, kubeconform, kind, act). Agent shells don't run the direnv hook, so run those tools as `direnv exec . <cmd>`.

    ## When to use skills
    - Editing a Helm chart: `chart-check` before pushing.
    - Reviewing or changing Kyverno policies: `kyverno-test`.
    - Bumping Go or cutting a release of a Go CLI (sparkctl, valhalla, ...): `go-bump-release`.
    - Before pushing changes to workflows, Makefiles, build/lint config or toolchain versions, or to reproduce a CI failure: `ci-local`.
  '';
    };
}
