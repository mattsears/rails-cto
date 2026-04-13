#!/usr/bin/env bash
# Stop hook: blocks completion if code files were changed but required quality gates were not run.
#
# Checks for modified .rb, .js, .erb, and .css files.
# Requires /rails-cto-qa, /rails-cto-security, and /rails-cto-static-analysis to have been invoked.
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

qa_marker="/tmp/claude-rails-cto-qa-loaded-${PPID}"
[[ -f "$qa_marker" ]] || missing+=("/rails-cto-qa")

# Security scan is required when .rb or .erb files were changed
security_pattern='\.(rb|erb)$'
sec_changes=$(echo "$changes" | grep -E "$security_pattern" || true)
sec_unstaged=$(echo "$unstaged" | grep -E "$security_pattern" || true)
sec_untracked=$(echo "$untracked" | grep -E "$security_pattern" || true)

if [[ -n "$sec_changes" || -n "$sec_unstaged" || -n "$sec_untracked" ]]; then
  security_marker="/tmp/claude-rails-cto-security-loaded-${PPID}"
  [[ -f "$security_marker" ]] || missing+=("/rails-cto-security")
fi

# Static analysis is required when .rb files were changed
sa_pattern='\.rb$'
sa_changes=$(echo "$changes" | grep -E "$sa_pattern" || true)
sa_unstaged=$(echo "$unstaged" | grep -E "$sa_pattern" || true)
sa_untracked=$(echo "$untracked" | grep -E "$sa_pattern" || true)

if [[ -n "$sa_changes" || -n "$sa_unstaged" || -n "$sa_untracked" ]]; then
  sa_marker="/tmp/claude-rails-cto-static-analysis-loaded-${PPID}"
  [[ -f "$sa_marker" ]] || missing+=("/rails-cto-static-analysis")
fi

# All required skills loaded
[[ ${#missing[@]} -gt 0 ]] || exit 0

# Block — list all missing skills
skills_list=$(IFS=', '; echo "${missing[*]}")
echo "{\"decision\":\"block\",\"reason\":\"Code files were modified but required quality gates have not been run: ${skills_list}. Invoke them before completing.\"}"
