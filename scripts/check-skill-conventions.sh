#!/usr/bin/env bash
# PreToolUse hook: blocks writing certain file types unless the required skills were loaded.
#
# Reads tool input JSON from stdin, extracts file_path, and checks for session
# markers created by mark-skill-loaded.sh. Uses PPID as a session proxy since
# Claude Code spawns hooks as child processes of the same parent.
#
# Enforced conventions:
#   *_test.rb            → /fullstack-rails-minitest
#   *.html.erb           → /fullstack-rails-erb, /fullstack-rails-tailwind
#   *.css                → /fullstack-rails-tailwind
#   */controllers/*.js   → /fullstack-rails-stimulus
#   */app/controllers/*.rb → /fullstack-rails-restful
#   */app/components/*     → /fullstack-rails-view-component
set -euo pipefail

input=$(cat)

# Extract file_path from tool input JSON
file_path=$(echo "$input" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')

# Determine which skills are required (if any)
required_skills=()

if [[ "$file_path" == *_test.rb ]]; then
  required_skills=(fullstack-rails-minitest)
elif [[ "$file_path" == *.html.erb ]]; then
  required_skills=(fullstack-rails-erb fullstack-rails-tailwind)
elif [[ "$file_path" == *.css ]]; then
  required_skills=(fullstack-rails-tailwind)
elif [[ "$file_path" == */controllers/*.js ]]; then
  required_skills=(fullstack-rails-stimulus)
elif [[ "$file_path" == */app/controllers/*.rb ]]; then
  required_skills=(fullstack-rails-restful)
elif [[ "$file_path" == */app/components/* ]]; then
  required_skills=(fullstack-rails-view-component)
fi

# Not a gated file type
[[ ${#required_skills[@]} -gt 0 ]] || exit 0

# Collect missing skills
missing=()
for skill in "${required_skills[@]}"; do
  marker="/tmp/claude-${skill}-loaded-${PPID}"
  [[ -f "$marker" ]] || missing+=("/$skill")
done

# All required skills loaded
[[ ${#missing[@]} -gt 0 ]] || exit 0

# Block — list all missing skills so Claude can load them before retrying
skills_list=$(IFS=', '; echo "${missing[*]}")
echo "{\"decision\":\"block\",\"reason\":\"Missing required skills: ${skills_list}. Invoke them before writing to this file type, then retry.\"}"
