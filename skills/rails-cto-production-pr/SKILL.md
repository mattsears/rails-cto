---
name: rails-cto-production-pr
description: Create a production pull request merging staging into main using the gh CLI. Use this skill whenever the user asks to create a production PR, deploy to production, cut a release, or says things like "release to production", "production PR", "deploy this", "ship to prod", "create a production PR", or "merge staging to main". Also triggers for "/production-pr". Do NOT use for creating feature PRs to staging — use rails-cto-pull-request for that.
---

# Production Release

Create a pull request to merge `staging` into `main` for a production release using the `gh` CLI.

## Workflow

### 1. Check for uncommitted changes

```bash
git status --porcelain
```

If there are any uncommitted or unstaged changes, warn the user and stop. Production releases should start from a clean working tree.

### 2. Fetch the latest

```bash
git fetch origin
```

### 3. Check for an existing release PR

```bash
gh pr list --head staging --base main --state open
```

If an open PR from `staging` to `main` already exists, warn the user with the existing PR link and stop.

### 4. Sync staging with main

Before creating the PR, merge `main` into `staging` so the branches stay in sync and the PR is clean.

Save the current branch so you can return to it later:

```bash
ORIGINAL_BRANCH=$(git branch --show-current)
```

Check out `staging` and merge `main` into it:

```bash
git checkout staging
git merge origin/main
```

If there are merge conflicts, try to resolve them. Read the conflicting files, understand both sides, and make the appropriate fix. After resolving, stage the resolved files and complete the merge:

```bash
git add -A
git merge --continue
```

If you cannot resolve the conflicts, abort the merge, return to the original branch, and tell the user which files have conflicts so they can handle it manually:

```bash
git merge --abort
git checkout "$ORIGINAL_BRANCH"
```

After a successful merge, push staging:

```bash
git push origin staging
```

### 5. Gather the changes

Review what `staging` has that `main` doesn't:

```bash
git log origin/main..origin/staging --oneline
git diff origin/main...origin/staging --stat
```

Read the commit messages and diffs to understand what changed and why.

### 6. Write the PR title

Use this exact format with today's date:

```
Production Release: mm-dd-yyyy
```

### 7. Write the PR description

Write the description in plain language that anyone can understand. Use emojis for section headers. Organize changes so readers can quickly tell what's significant and what's minor.

Do NOT include co-authorship lines or reference "Claude" or any AI tool anywhere. Do NOT list individual files changed.

Use this structure:

```markdown
## 🚀 Summary

A 1-2 sentence overview of what this release includes and why it matters.

## 🔥 Major Changes

- Describe significant changes here — new features, important fixes, behavior changes
- Each bullet should explain what changed from a user or product perspective
- Include enough context that someone unfamiliar with the code understands the impact

## 🔧 Minor Changes

- Small tweaks, formatting fixes, config updates, copy changes
- Things that are good to know about but don't need close review

## 🧪 Test Plan

- Describe what should be tested before deploying
- List specific areas to verify based on the changes
- Do not use checkboxes — use plain bullet points
```

If there are only major changes, omit the "Minor Changes" section. If everything is minor, omit "Major Changes." Use your judgment.

### 8. Create the PR

```bash
gh pr create --base main --head staging --title "Production Release: mm-dd-yyyy" --body "$(cat <<'EOF'
## 🚀 Summary
...

## 🔥 Major Changes
...

## 🔧 Minor Changes
...

## 🧪 Test Plan
...
EOF
)"
```

After creation, show the user the PR URL.

### 9. Return to the original branch

```bash
git checkout "$ORIGINAL_BRANCH"
```

Return the user to whatever branch they were on before running this skill.
