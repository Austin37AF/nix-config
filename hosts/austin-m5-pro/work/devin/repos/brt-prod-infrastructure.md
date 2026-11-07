# Personal notes: brt-prod-infrastructure (not committed; linked from ~/homelab/nix)

## Layout
- `terraform/<account>/`: `aws-isg-brtinfra-prod` (infra, 381492297234), `aws-isg-brtplat-devl` (dev, 975050219078), `aws-isg-brtplat-prod` (prod, 471112691876), plus `newrelic/`, `rootly/` and shared `modules/`.
- `gitops/<cluster>/`: ArgoCD Applications per cluster; charts in `gitops/charts/` (`argocd-bootstrap`, `bootstrap`, `kyverno-policies`, ...).
- `services/<name>/`: per-service `service.yaml`, charts and terraform (sparkai, sil, airflow, jfa-analytics-platform). Schemas in `schemas/`, Go tools in `cmd/`.

## Terraform
- Applied only through Atlantis (`atlantis.yaml` lists projects and autoplan paths). Never `apply` locally; `fmt`/`validate` are fine, `plan` only when asked.
- `check-terraform-up-to-date` fails a PR if main changed the same workspace since the merge base: rebase onto `origin/main` before pushing terraform changes.

## Before pushing
- `pre-commit run --all-files` (what CI runs): yaml checks, jsonschema for `services/*/service.yaml`, prettier on service definitions, detect-secrets, terraform fmt, SIL validators.
- `make destination-validator` when ArgoCD Applications under `gitops/` change.
- Changes under `services/sil/charts/**` or `gitops/charts/argocd-bootstrap/templates/sil/**` dispatch SIL runner tests on the PR.

## Local testing
- Chart changes: use the `chart-check` skill.
- Kyverno policies (`gitops/charts/kyverno-policies`, Kyverno chart version in `gitops/<env>/kyverno-service-<env>.yaml`): use the `kyverno-test` skill.

## Access
- AWS via `valhalla init -p ADFS-ISG-BRT-PRODUCTION-ENGINEERING` (use the `-RO` role for investigation). Log in to Deere Cloud in the browser first.
