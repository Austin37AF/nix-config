---
name: go-bump-release
description: Bump the Go version of a Go CLI repo (sparkctl, valhalla, or similar), open the PR, and after it merges cut a release and verify the published binaries were built with that Go. Use for Go security patch rollouts or any "rebuild with a newer Go" request.
---

## Rules
- Run Go through the folder's dev shell: `direnv exec . go ...` (outside ~/brt-projects and ~/sparkai-projects use `nix shell nixpkgs#go -c go ...`).
- Pushing a tag publishes a release and, in these repos, updates the version that users' update checks see. Ask the user for the version before tagging.
- Clone missing sparkai repos with `~/sparkai-projects/z-clone-sparkai.sh <repo>` (run from `~/sparkai-projects`; argument is the bare repo name) and BRT repos with `~/brt-projects/z-brt-clone.sh <repo>` (run from `~/brt-projects`), so the repo gets the user's identity.

## 1. Bump
- `git switch main && git pull --ff-only && git switch -c fix/go-<version>` (sparkai repos: `fix/SPRK-0000-go-<version>`).
- `go mod edit -go=<version>`. Don't add a `toolchain` line; run `go mod tidy` only if the build needs it.
- Find every other Go pin: `devbox.json`/`devbox.lock`, `Dockerfile` (`golang:` tags), `.goreleaser.yaml`, `Makefile`, `.github/workflows/*` (`go-version`).
  - Workflows should use `go-version-file: go.mod`. A floating `go-version: "1.xx"` lets setup-go pick an older cached patch, and setup-go sets `GOTOOLCHAIN=local`, so CI fails against the new go.mod minimum. Switch them in the same PR.
  - Bump exact-patch pins that are below the target. If devbox can't resolve the new version (`package not found`), leave devbox unchanged and say so in the PR.
- Verify: the repo's own build and test targets (`make test`, `make build`, or `go build ./... && go vet ./... && go test ./...`), then `go version <built binary>` shows the target. Private modules: `GOPRIVATE=github.com/sparkai-corp/*`.

## 2. PR
- Match the repo's title style (sparkai: `SPRK-0000: Require Go <version>`; valhalla: `fix: require Go <version>`).
- Body: why (the advisory or patch), which pins changed and which were left (with reasons), and a test plan with "cut a release after merge" unchecked.
- Wait for CI with `gh pr checks <n> --watch`; on failure read the log (`gh run view <id> --log-failed`), fix on the branch, and update the PR body.

## 3. Release (after merge, with the user's go-ahead)
- `git switch main && git pull --ff-only && git fetch --tags`; list changes since the last tag (`git log --oneline <last-tag>..HEAD`).
- Propose a version using the README's semver rules (new command → minor; fixes/config only → patch) and ask the user.
- Tag the merge commit (lightweight, like existing tags): `git tag v<x.y.z> <sha> && git push origin v<x.y.z>`.
- Watch every run for the tag (`gh run list` filtered by the tag, `gh run watch <id> --exit-status`): goreleaser, version sync, CI.
- Download one published asset (`gh release download v<x.y.z> -p '*linux_amd64*'`), extract it in a temp dir, and check `go version <binary>`.

## Report
PR link and status, tag, workflow results, the published binary's Go version, and anything left (devbox pins, other repos, the user's local install).
