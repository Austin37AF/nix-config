---
name: chart-check
description: Validate Helm chart changes locally the way CI does (lint and render every values file, helm unittest, schema validation) and diff the rendered output against main. Use after editing a chart in gitops/charts, services/*/charts or charts/.
---

Check changed charts without touching any cluster, and report what the change does to the rendered manifests.

## 1. Find changed charts
- `git fetch origin main`, then `git diff --name-only origin/main...HEAD` (plus uncommitted changes).
- Map files to chart directories (the nearest parent containing `Chart.yaml`).
- Note ArgoCD Applications that point at those charts and which values files they use.

## 2. Lint and render
Scratch output in `/tmp/chart-check/<chart>/<head|main>/`.
- If `Chart.yaml` has dependencies: `helm dependency build <chart>`. If that needs a Helm repo you don't have, say which before adding it.
- For every `values*.yaml` (and the combinations CI uses): `helm lint <chart> -f <values>` and `helm template <name> <chart> -f <values> > /tmp/chart-check/<chart>/head/<values>.yaml`.
- sparkai gitops `charts/sparkai-core` CI combinations: `values-staging.yaml`, `values-staging-sandbox.yaml`, and `values-prod.yaml` + `prod-tags.yaml`.

## 3. Unit tests
- If the chart has a `tests/` directory: `helm unittest <chart>`.
- CI uses helm-unittest 1.1.2; the local plugin may be older. If results differ, say so rather than changing the plugin.
- Never update snapshots (`-u`) unless asked; report snapshot diffs instead.

## 4. Schema validation
- `nix shell nixpkgs#kubeconform -c kubeconform -strict -ignore-missing-schemas -summary /tmp/chart-check/<chart>/head/*.yaml`
- CRD-based resources are skipped by `-ignore-missing-schemas`; list which kinds were skipped.

## 5. Diff against main
- Render the same values from a worktree of `origin/main` (`git worktree add /tmp/chart-check/main-src origin/main`) into `.../main/`.
- `diff -u` main vs head per values file. Summarize meaningful changes: images and tags, resources, env and secrets references, RBAC, selectors and labels, ingress, anything removed.

## 6. Repo checks
- brt-prod-infrastructure: `make destination-validator` if ArgoCD Applications changed; `pre-commit run --files <changed files>`.
- sparkai gitops: `cd cmd/destination-validator && go run main.go`; `prettier -c .`.

## 7. Optional server-side dry run
Only when asked: `kubectl --context docker-desktop apply --dry-run=server -f <rendered>` (CRDs must exist on the cluster; skip kinds that don't).

## 8. Cleanup
`git worktree remove /tmp/chart-check/main-src` and `rm -rf /tmp/chart-check`.

## Report
Per chart and values file: lint, render, unittest, schema results, then the summarized diff vs main. Lead with failures.
