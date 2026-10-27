---
name: kyverno-test
description: Test a Kyverno policy (for example from a PR) on the local docker-desktop cluster, at the Kyverno version the real clusters run, then clean up completely. Use when reviewing or changing a kyverno-policies chart.
---

Test the policy against realistic resources, compare base vs change, and leave the cluster exactly as you found it.

## Rules
- Pass `--context docker-desktop` to every `kubectl` command and `--kube-context docker-desktop` to every `helm` command. Never touch any other cluster.
- Keep scratch files in `/tmp/kyverno-test/`.
- Cleanup (step 6) is mandatory, including after a failure. Leftover Kyverno webhooks block pod creation on the cluster.

## 1. Preflight and starting state
- `kubectl --context docker-desktop get nodes` must succeed (Docker Desktop Kubernetes running).
- Record, for cleanup: `kubectl get ns`, `helm list -A`, node labels and taints, `helm repo list`.

## 2. Find versions and render policies
- Kyverno chart version: `targetRevision` of the kyverno Application
  - brt-prod-infrastructure: `gitops/<env>/kyverno-service-<env>.yaml`
  - sparkai gitops: `<env>/kyverno-service-<env>.yaml`
- Policies chart: `gitops/charts/kyverno-policies` (brt) or `charts/kyverno-policies` (sparkai), with the matching `values-<env>.yaml`.
- For a PR, check out base and PR into git worktrees under `/tmp/kyverno-test/` and render each:
  `helm template kp <chart> -f <chart>/values-<env>.yaml > /tmp/kyverno-test/<base|pr>/policies.yaml`

## 3. Fast check with the Kyverno CLI (no cluster)
- Get the CLI matching the chart's appVersion (`helm show chart kyverno/kyverno --version <ver>`) into `/tmp/kyverno-test/`.
- Write test resources covering both allowed and denied/mutated cases, labelled like real workloads (namespaces, team labels, tolerations).
- `kyverno apply policies.yaml -r resources.yaml [--values-file values.yaml] -o mutated.yaml` for base and PR.

## 4. Admission test on docker-desktop
- `helm repo add kyverno https://kyverno.github.io/kyverno` (note whether it was already present).
- `helm install kyverno kyverno/kyverno -n kyverno --create-namespace --version <ver> --kube-context docker-desktop --wait`
- Apply the rendered policies, wait for them to be ready, create a `kyverno-test` namespace labelled like the real target, then apply the test resources.
- Add node labels or taints only if a policy depends on them, and record each one.
- Capture admitted / denied (error message) / mutated (`kubectl get -o yaml`) for each case. Repeat with the other policy version.

## 5. Report
A table: case, expected, base result, PR result. Call out regressions and anything the CLI and admission results disagree on.

## 6. Cleanup (always)
- Delete test resources and the `kyverno-test` namespace, then the policies (`kubectl delete -f`).
- `helm uninstall kyverno -n kyverno --kube-context docker-desktop`, delete the `kyverno` namespace.
- Confirm nothing is left: `kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations`, `kubectl get crd | grep kyverno`, `kubectl get clusterroles,clusterrolebindings | grep kyverno`. Delete leftovers.
- Remove node labels and taints you added. Remove Helm repos only if you added them.
- `git worktree remove` each worktree, `rm -rf /tmp/kyverno-test`.
- Compare against the starting state from step 1 and report that it matches.
