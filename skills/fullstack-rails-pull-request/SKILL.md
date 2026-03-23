---
name: fullstack-rails-pull-request
description: Create a pull request targeting the staging branch using the gh CLI. Use this skill whenever the user asks to create a PR, open a pull request, submit for review, or says things like "create a PR", "open a pull request", "submit this for review", "PR this", or "send this to staging". Also triggers for "/pull-request" or "/pr". Do NOT use for merging PRs, reviewing PRs, or creating production releases.
---

# Pull Request

Create a pull request from the current branch into `staging` using the `gh` CLI. The PR should be easy to understand for anyone — technical or not.

## Workflow

### 1. Preflight checks

**Check the current branch:**

```bash
git branch --show-current
```

If the current branch is `staging`, stop and tell the user: "You're on the staging branch — this skill creates PRs that target staging from a feature branch. Switch to your working branch first."

**Check for an existing PR:**

```bash
gh pr list --head "$(git branch --show-current)" --base staging --state open
```

If a PR already exists for this branch targeting `staging`, warn the user with the existing PR link and stop. Do not create a duplicate.

### 2. Commit outstanding changes

If there are any uncommitted or unstaged changes, commit them first using the `fullstack-commit` skill before continuing. This ensures everything is captured in the PR.

### 3. Push to remote

Push the branch to the remote repository. If the branch has no upstream, set one:

```bash
git push -u origin "$(git branch --show-current)"
```

If it already tracks a remote, a simple `git push` is fine.

### 4. Gather the changes

Review what this branch has changed relative to `staging`:

```bash
git log staging..HEAD --oneline
git diff staging...HEAD --stat
```

Read the commit messages and the actual diffs to understand what changed and why.

### 5. Write the PR title

Write a short, plain-language title (under 72 characters) that describes what this branch accomplishes. Same rules as commit messages — no jargon, no technical shorthand, readable by anyone.

**Good examples:**
- `Add password reset flow for logged-out users`
- `Fix checkout button not working on mobile`
- `Update pricing page with annual discount`

### 6. Write the PR description

Write the description in plain language. Organize changes into two sections so readers can quickly tell what's significant and what's minor.

Do NOT include co-authorship lines or reference "Claude" or any AI tool anywhere.

Use this structure:

```markdown
## Summary

A 1-2 sentence overview of what this branch does and why.

## Major Changes

- Describe significant changes here — new features, important fixes, behavior changes
- Each bullet should explain what changed from a user or product perspective
- Include enough context that someone unfamiliar with the code understands the impact

## Minor Changes

- Small tweaks, formatting fixes, config updates, copy changes
- Things that are good to know about but don't need close review
```

If there are only major changes, omit the "Minor Changes" section. If everything is minor, omit "Major Changes." Use your judgment — the point is to help the reader focus their attention.

### 7. Create the PR

```bash
gh pr create --base staging --title "the pr title" --body "$(cat <<'EOF'
## Summary
...

## Major Changes
...

## Minor Changes
...
EOF
)"
```

After creation, show the user the PR URL so they can view it.
