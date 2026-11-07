---
name: pr-review
description: Review a pull request or the current branch's changes for bugs, risks and missing tests. Use when asked to review a PR, review a diff, or check changes before merging.
---

# PR Review

## 1. Get the diff

- If given a PR number or URL: run `gh pr view <n>` for the title/description, then `gh pr diff <n>`.
- Otherwise review the current branch against its base:
  1. `base=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)`
  2. `git diff --stat "$base"...HEAD`
  3. `git diff "$base"...HEAD`
- If the diff is large, review it file by file (`git diff "$base"...HEAD -- <path>`) instead of all at once.

## 2. Understand before judging

- Read the PR description or commit messages (`git log --oneline "$base"..HEAD`) to learn the intent.
- For every changed function, open the surrounding code with `read_file` and find callers with `grep`. Do not judge a hunk in isolation.
- Check `diagnostics` for changed files.

## 3. Look for, in priority order

1. Correctness bugs: logic errors, off-by-one, null/None handling, wrong conditions, broken error paths.
2. Security: injection, secrets in code or logs, missing auth checks, unsafe deserialization.
3. Breaking changes: changed signatures, config, schemas or behaviour that callers depend on.
4. Concurrency and resource issues: races, leaks, unclosed handles, unbounded growth.
5. Missing or weak tests for the changed behaviour.
6. Readability only when it materially hurts maintenance.

## 4. Rules

- Only report issues you can point to in the code. If unsure, say so and explain what would confirm it.
- Do not report style nitpicks a formatter or linter would catch.
- Do not edit files. This is a review, not a fix.
- If there are no real issues, say so plainly.

## 5. Output format

```
## Summary
<1-2 sentences: what the change does and overall verdict>

## Issues
### [High|Medium|Low] <short title>
<file>:<line>
<what is wrong, why it matters, suggested fix>

## Tests
<what is covered, what is missing>
```
