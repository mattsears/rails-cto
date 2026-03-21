# My Development Environment

I do NOT use Docker for local development. Please DO NOT prefix  commands with `bin/dock`:

# Skills

When working on Ruby on Rails projects, always invoke `/fullstack-rails-cto` at the start of a session. It handles skill routing, QA gates, and the completion checklist.

## Mandatory: After Modifying Any `.rb` File

Invoke `/fullstack-rails-qa` after every code change. A task is NOT done until QA passes. Do not skip this even if the user doesn't mention it.

## Mandatory: After Modifying Any `.html.erb` File

Invoke `/fullstack-rails-erb` and `/fullstack-rails-tailwind` after every ERB change. A task is NOT done until ERB and Tailwind checks pass. Do not skip this even if the user doesn't mention it.

## Mandatory: Every Plan Must Include QA

When creating any implementation plan, always include `/fullstack-rails-qa` as a final step. No plan is complete without a QA gate.
