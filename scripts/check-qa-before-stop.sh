#!/usr/bin/env bash
# Stop hook: blocks completion if code files were changed but required quality gates were not run.
#
# Checks for modified .rb, .js, .erb, and .css files.
# Requires both /fullstack-rails-qa and /fullstack-rails-security to have been invoked.
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

# Check which required skills are missing
missing=()

qa_marker="/tmp/claude-fullstack-rails-qa-loaded-${PPID}"
[[ -f "$qa_marker" ]] || missing+=("/fullstack-rails-qa")

# Security scan is required when .rb or .erb files were changed
security_pattern='\.(rb|erb)$'
sec_changes=$(echo "$changes" | grep -E "$security_pattern" || true)
sec_unstaged=$(echo "$unstaged" | grep -E "$security_pattern" || true)
sec_untracked=$(echo "$untracked" | grep -E "$security_pattern" || true)

if [[ -n "$sec_changes" || -n "$sec_unstaged" || -n "$sec_untracked" ]]; then
  security_marker="/tmp/claude-fullstack-rails-security-loaded-${PPID}"
  [[ -f "$security_marker" ]] || missing+=("/fullstack-rails-security")
fi

# All required skills loaded
[[ ${#missing[@]} -gt 0 ]] || exit 0

# Block — list all missing skills
skills_list=$(IFS=', '; echo "${missing[*]}")
echo "{\"decision\":\"block\",\"reason\":\"Code files were modified but required quality gates have not been run: ${skills_list}. Invoke them before completing.\"}"
