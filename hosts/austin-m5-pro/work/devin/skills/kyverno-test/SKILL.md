---
name: kyverno-test
description: Test a Kyverno policy (for example from a PR) on a throwaway local kind cluster, at the Kubernetes and Kyverno versions the real clusters run, then delete the cluster. Use when reviewing or changing a kyverno-policies chart.
---

Test the policy against realistic resources, compare base vs change, and leave nothing behind.

## Rules
- Run tools through the folder's dev shell: prefix commands with `direnv exec .` (agent shells don't load direnv). Example: `direnv exec . kind get clusters`.
- The cluster gets its own kubeconfig, `/tmp/kyverno-test/kubeconfig`, so `~/.kube/config` and its current context are never touched. All changes happen on that cluster: pass `--kubeconfig /tmp/kyverno-test/kubeconfig --context kind-kyverno-test` to every `kubectl` command and `--kubeconfig /tmp/kyverno-test/kubeconfig --kube-context kind-kyverno-test` to every `helm` command that touches it. Other contexts are read-only (step 1 only).
- Keep scratch files in `/tmp/kyverno-test/`.
- Cleanup (step 7) is mandatory, including after a failure.

## 1. Preflight and versions
- Docker Desktop must be running (`docker info`); its built-in Kubernetes is not needed.
- If `kind get clusters` already lists `kyverno-test`, stop and ask: it may be another session's.
- Target Kubernetes version: ask which cluster the policy is for, then read it (read-only) with `kubectl --context <ctx> version -o json` (`serverVersion.gitVersion`).
- Kyverno chart version: `targetRevision` of the kyverno Application
  - brt-prod-infrastructure: `gitops/<env>/kyverno-service-<env>.yaml`
  - sparkai gitops: `<env>/kyverno-service-<env>.yaml`

## 2. Render policies
- Policies chart: `gitops/charts/kyverno-policies` (brt) or `charts/kyverno-policies` (sparkai), with the matching `values-<env>.yaml`.
- For a PR, check out base and PR into git worktrees under `/tmp/kyverno-test/` and render each:
  `helm template kp <chart> -f <chart>/values-<env>.yaml > /tmp/kyverno-test/<base|pr>/policies.yaml`

## 3. Fast check with the Kyverno CLI (no cluster)
- The dev shell has a `kyverno` CLI; note its version vs the chart's appVersion (`helm show chart kyverno/kyverno --version <ver>`). If they differ by a minor version, say so in the report.
- Write test resources covering allowed and denied/mutated cases, labelled like real workloads (namespaces, team labels, tolerations).
- `kyverno apply policies.yaml -r resources.yaml [--values-file values.yaml] -o mutated.yaml` for base and PR.

## 4. Create the cluster
- Pick the `kindest/node` image for the target minor version from the installed kind release's notes (`kind version`; images are listed at https://github.com/kubernetes-sigs/kind/releases). Use the exact patch if listed, else the newest patch of that minor, and report which.
- `kind create cluster --name kyverno-test --image kindest/node:<version>@<digest> --config ~/.config/kind/cluster.yaml --kubeconfig /tmp/kyverno-test/kubeconfig --wait 2m`. The config mounts the Zscaler CA bundle so the node can pull images; without it pulls fail with `x509: certificate signed by unknown authority`.
- The first use of a node image may pull only the amd64 variant if `DOCKER_DEFAULT_PLATFORM` leaked in; the Nix `kind` wrapper unsets it. Confirm `docker exec kyverno-test-control-plane uname -m` is `aarch64`.
- Add node labels or taints only if a policy depends on them.

## 5. Admission test
- `helm repo add kyverno https://kyverno.github.io/kyverno` (note whether it was already present).
- `helm install kyverno kyverno/kyverno -n kyverno --create-namespace --version <ver> --kubeconfig /tmp/kyverno-test/kubeconfig --kube-context kind-kyverno-test --wait`
- Apply the rendered base policies, wait until they're ready, create a `kyverno-test` namespace labelled like the real target, then apply the test resources.
- Capture admitted / denied (error message) / mutated (`kubectl get -o yaml`) for each case.
- Delete the policies and test resources, then repeat with the PR policies on the same cluster.

## 6. Report
Versions used (Kubernetes image, Kyverno chart, CLI), then a table: case, expected, base result, PR result. Call out regressions and anything the CLI and admission results disagree on.

## 7. Cleanup (always)
- `kind delete cluster --name kyverno-test --kubeconfig /tmp/kyverno-test/kubeconfig`; confirm `kind get clusters` no longer lists it and `kubectl config get-contexts` (the default kubeconfig) has no `kind-*` entries.
- Remove the Helm repo only if you added it.
- `git worktree remove` each worktree, `rm -rf /tmp/kyverno-test`.
