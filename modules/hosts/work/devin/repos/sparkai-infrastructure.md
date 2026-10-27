# Personal notes: sparkai infrastructure (not committed; linked from ~/homelab/nix)

## Layout
- Terraform for SparkAI, mostly GCP: one root per directory (`infra`, `staging`, `prod`, `analytics`, `auth0`, `dr`, `gh-actions`, `log-aggregation`, `midwest`, `org`, `sparkai-aws-iam`, `deere-cloud-dev`, `utils`) with shared `modules/`. Atlantis projects in `atlantis.yaml`.

## Terraform
- Applied only through Atlantis. Never `apply` locally; `plan` only when asked.
- CI only runs `terraform fmt -recursive -check`: run `terraform fmt -recursive` before committing.
- After `terraform init`, lock providers for every platform (see README): `terraform providers lock -platform=darwin_amd64 -platform=darwin_arm64 -platform=linux_arm64 -platform=linux_amd64`.
- In interactive shells `terraform` is aliased to `tofu`.

## Access
- GCP: `gcloud auth login --update-adc`.
