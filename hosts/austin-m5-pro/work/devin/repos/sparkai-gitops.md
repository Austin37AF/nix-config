# Personal notes: sparkai gitops (not committed; linked from ~/homelab/nix)

## Layout
- ArgoCD on the infra cluster deploys everything, bootstrapped from `infra/bootstrap/argocd-bootstrap.yaml`. `infra/` affects every environment: call out any change there.
- Applications per environment in `staging/`, `prod/`, `analytics/`; charts in `charts/`.

## Before pushing (what CI runs)
- `prettier -c .` (fix with `prettier -w .`).
- Destination validator: `cd cmd/destination-validator && go run main.go`.
- `charts/sparkai-core`: from the chart dir, `helm template .` with `-f values-staging.yaml`, `-f values-staging-sandbox.yaml`, and `-f values-prod.yaml -f prod-tags.yaml`; then `helm unittest charts/sparkai-core` from the repo root. CI uses helm-unittest 1.1.2. Use the `chart-check` skill.

## Local testing
- Kyverno: chart version in `prod/kyverno-service-prod.yaml`, policies in `charts/kyverno-policies`. Use the `kyverno-test` skill.

## Clusters
- `gke_sparkai-infra_us-central1_infra-cluster` and `gke_sparkai-prod_us-central1_prod-cluster`: read-only.
