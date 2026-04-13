#!/usr/bin/env bash
# PostToolUse hook: creates session markers when gated skills are invoked.
set -euo pipefail

input=$(cat)

for skill in rails-cto-minitest rails-cto-erb rails-cto-tailwind rails-cto-stimulus rails-cto-restful rails-cto-view-component rails-cto-qa rails-cto-security rails-cto-static-analysis; do
  if echo "$input" | grep -q "$skill"; then
    touch "/tmp/claude-${skill}-loaded-${PPID}"
  fi
done
