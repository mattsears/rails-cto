#!/usr/bin/env bash
# PostToolUse hook: creates session markers when gated skills are invoked.
set -euo pipefail

input=$(cat)

for skill in fullstack-rails-minitest fullstack-rails-erb fullstack-rails-tailwind fullstack-rails-stimulus fullstack-rails-restful fullstack-rails-view-component fullstack-rails-qa; do
  if echo "$input" | grep -q "$skill"; then
    touch "/tmp/claude-${skill}-loaded-${PPID}"
  fi
done
