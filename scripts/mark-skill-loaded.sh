#!/usr/bin/env bash
# PostToolUse hook: creates session markers when gated skills are invoked.
set -euo pipefail

input=$(cat)

for skill in rails-cto rails-cto-api rails-cto-architect rails-cto-commit rails-cto-engineer rails-cto-erb rails-cto-minitest rails-cto-production-pr rails-cto-pull-request rails-cto-qa rails-cto-restful rails-cto-security rails-cto-static-analysis rails-cto-stimulus rails-cto-tailwind rails-cto-upgrade rails-cto-view-component; do
  if echo "$input" | grep -qE "${skill}([^a-zA-Z0-9_-]|\$)"; then
    touch "/tmp/claude-${skill}-loaded-${PPID}"
  fi
done
