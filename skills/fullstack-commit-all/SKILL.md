---
name: fullstack-commit-all
description: Stage and commit all outstanding code changes with a clear, human-friendly commit message. Use this skill whenever the user asks to commit, save their work, push changes, or says things like "commit this", "save my progress", "push this up", "ship it", "commit all", or "commit and push". Also triggers for "/commit-all". Do NOT use for cherry-picking, rebasing, or other advanced git operations.
---

# Commit

Stage and commit all outstanding changes with a clear, human-friendly message. Optionally push to the remote — but only after the user confirms.

## Workflow

### 1. Gather context

Run these in parallel to understand what's changed:

- `git status` — see untracked and modified files
- `git diff` — see unstaged changes
- `git diff --cached` — see already-staged changes
- `git log --oneline -5` — see recent commit style for reference

If there are no changes to commit (nothing untracked, nothing modified, nothing staged), tell the user and stop.

### 2. Stage everything

Add all changes — tracked and untracked — to the staging area:

```bash
git add -A
```

If any files look like they contain secrets (`.env`, credentials, tokens, API keys), warn the user and exclude them before committing.

### 3. Write the commit message

Write a commit message that a non-technical person could understand. The goal is clarity — someone glancing at the git log should immediately know what changed and why.

**Rules:**
- Use plain language. Avoid jargon, abbreviations, and technical shorthand.
- Lead with what the change accomplishes from a user or product perspective, not implementation details.
- Keep the subject line under 72 characters.
- If the change is complex, add a blank line and a short body paragraph explaining the "why."
- Do NOT include any co-authorship lines (no `Co-Authored-By`).
- Do NOT reference "Claude" or any AI tool in the message.

**Good examples:**
- `Add password reset flow for logged-out users`
- `Fix broken checkout button on mobile screens`
- `Update pricing page to show annual discount`
- `Remove unused admin dashboard pages`

**Bad examples:**
- `refactor: extract util fn for auth middleware` (too technical)
- `fix bug` (too vague)
- `WIP` (not descriptive)
- `Update files` (says nothing)

Use a HEREDOC to pass the message so multi-line messages format correctly:

```bash
git commit -m "$(cat <<'EOF'
Your commit subject line here

Optional body explaining why, if needed.
EOF
)"
```

### 4. Confirm before pushing

After committing, ask the user if they want to push to the remote. Do not push automatically.

If they say yes:
- If the branch has no upstream, use `git push -u origin <branch>` to set tracking.
- If it does, use `git push`.
- Never force-push unless the user explicitly asks for it.
- Warn and refuse if the target is `main` or `master` (unless the user insists).

If they say no or don't mention pushing, just confirm the commit was made and stop.
