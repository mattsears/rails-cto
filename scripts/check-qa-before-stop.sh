#!/usr/bin/env bash
# Stop hook: blocks completion if code files were changed but /fullstack-rails-qa was not run.
#
# Checks for modified .rb, .js, .erb, and .css files.
# Uses the same PPID-based session marker pattern as the other hooks.
set -euo pipefail

# Check if any code files were modified in the working tree
pattern='\.(rb|js|erb|css)$'
changes=$(git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null | grep -E "$pattern" || true)
unstaged=$(git diff --name-only --diff-filter=ACMR 2>/dev/null | grep -E "$pattern" || true)
untracked=$(git ls-files --others --exclude-standard 2>/dev/null | grep -E "$pattern" || true)

if [[ -z "$changes" && -z "$unstaged" && -z "$untracked" ]]; then
  # No code files changed — nothing to gate
  exit 0
fi

# Check if QA skill was loaded this session
marker="/tmp/claude-fullstack-rails-qa-loaded-${PPID}"
if [[ -f "$marker" ]]; then
  exit 0
fi

# Block — Claude must run QA before finishing
echo '{"decision":"block","reason":"Code files (.rb, .js, .erb, or .css) were modified but /fullstack-rails-qa has not been run. Invoke the QA skill to run linting and tests before completing."}'
