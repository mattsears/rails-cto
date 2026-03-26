# My Development Environment

I do NOT use Docker for local development. Please DO NOT prefix  commands with `bin/dock`:

# Skills

When working on Ruby on Rails projects, always invoke `/fullstack-rails-cto` at the start of a session. It handles skill routing, QA gates, and the completion checklist.

## Mandatory: Skill Routing by File Type

Before planning or modifying any file, read the relevant skill(s) first. Follow the conventions in each skill — do not deviate without consulting it. Multiple skills may apply to a single change.

| When you touch... | Read these skills first |
|---|---|
| Any `.rb` file | `/fullstack-rails-engineer` |
| Files in `app/controllers/` (except API) | `/fullstack-rails-restful` |
| Files in `app/controllers/api/` | `/fullstack-rails-api`, `/fullstack-rails-restful` |
| Files in `app/models/` or `app/commands/` or `app/services/` | `/fullstack-rails-engineer` |
| Files in `app/components/` | `/fullstack-rails-view-component` |
| Files in `app/frontend/controllers/` (Stimulus) | `/fullstack-rails-stimulus` |
| Any `.html.erb` file | `/fullstack-rails-erb`, `/fullstack-rails-tailwind` |
| Any `.css` or Tailwind-related file | `/fullstack-rails-tailwind` |
| Any test file in `test/` | `/fullstack-rails-minitest` |

## Mandatory: After Modifying Any `.rb` File

Invoke `/fullstack-rails-qa` after every code change. A task is NOT done until QA passes. Do not skip this even if the user doesn't mention it.

## Mandatory: After Modifying Any `.html.erb` File

Invoke `/fullstack-rails-erb` and `/fullstack-rails-tailwind` after every ERB change. A task is NOT done until ERB and Tailwind checks pass. Do not skip this even if the user doesn't mention it.

**Herb is required on every changed ERB file — new or existing.** After modifying any `.html.erb` file, run `bundle exec herb --fix` and `bundle exec herb format` on it. This applies to all ERB files you touch, not just new ones. Review the output and fix any errors or warnings that Herb reports — do not ignore them or move on until they are resolved.

## Mandatory: Every Plan Must Include QA

When creating any implementation plan, always read `/fullstack-rails-engineer` first to understand the project's best practices, conventions, and implementation flow. Follow its guidance on searching for reusable code, service objects, concerns, and existing patterns before proposing new code. Then include `/fullstack-rails-qa` as a final step. No plan is complete without a QA gate.
