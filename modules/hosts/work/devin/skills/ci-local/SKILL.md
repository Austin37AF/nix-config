---
name: ci-local
description: Run a repo's GitHub Actions CI jobs locally with act to catch failures before pushing. Use before pushing changes to workflows, Makefiles, build or lint config, dependency or toolchain versions, or to reproduce a CI failure.
---

Run the jobs a PR would run, report what passed, failed or couldn't run locally, and never publish anything.

## Rules
- Run act through the folder's dev shell: `direnv exec . act ...` (outside ~/brt-projects and ~/sparkai-projects: `nix develop ~/homelab/nix -c act ...`).
- `~/.actrc` (managed by Nix) already sets the runner images, linux/amd64, and the Zscaler CA bundle for job containers. Don't override those flags.
- Only run `pull_request` (or `push` to a branch) events. Never run tag, `release`, `workflow_dispatch` deploy, or schedule workflows, and never run jobs that publish or deploy: goreleaser, `docker push`/ECR/GAR pushes, `gh release`, syncs to S3/GCS, Helm/OCI pushes, Terraform apply. Act would use real credentials if they were given.
- Secrets: only `GITHUB_TOKEN`, passed by name from the environment so it never appears in the command line: `GITHUB_TOKEN="$(gh auth token)" direnv exec . act ... -s GITHUB_TOKEN`. Never pass cloud credentials, PEM keys or other secrets.
- Always `--rm` so job containers are removed.

## 1. Plan
- `act -l` (and `act pull_request -l`) to list workflows and jobs for the event.
- For each job, read its steps and classify:
  - runnable: checkout, setup-* actions, make/go/npm/helm/terraform fmt-validate, linters, tests
  - not runnable locally: OIDC or cloud auth (`id-token: write`, `aws-actions/configure-aws-credentials`, `google-github-actions/auth`), GitHub App token actions (e.g. `sparkai-corp/gha-private-auth`) and anything that depends on their output, registry logins and pushes, deploys
- Show the plan (which jobs run, which are skipped and why) before running.

## 2. Run
- One job at a time: `act pull_request -j <job> --rm` (add `-W .github/workflows/<file>.yml` when job names repeat across files; `--matrix key:value` to pick one matrix entry).
- A job whose only blocker is private Go modules via a GitHub App token: instead of act, run its commands directly in the dev shell with `GOPRIVATE` set (the user's git/gh credentials can read the repos), and say that the job was emulated, not run by act.
- On failure: read the failing step's output, find the cause in the repo, and propose (or, if asked, make) the fix; rerun the job to confirm.

## 3. Report
Per job: ran / emulated / skipped (reason), and per step pass or fail with the key error lines. Then the known gaps between act and GitHub:
- runner image differs (act uses catthehacker images; GitHub's toolcache and preinstalled versions differ). Version-resolution issues like a floating `go-version` picking an older cached patch may not reproduce;
- jobs run as linux/amd64 under emulation, so they're slower and timing-sensitive tests may differ;
- `Post actions/setup-*` cleanup steps can fail with `exec: "node": executable file not found` (an act limitation); ignore those when the main steps passed;
- skipped auth, push and deploy steps are only verified on GitHub (push a branch and `gh run watch`).

## Cleanup
`--rm` removes containers. Leave act's cached images and action clones (`~/.cache/act`) in place; they're reused. Remove any scratch files you created.
