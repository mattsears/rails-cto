# Skills

When working on Ruby on Rails projects, always invoke `/rails-cto` at the start of a session. It handles skill routing, QA gates, and the completion checklist.

## Mandatory: Skill Routing by File Type

Before planning or modifying any file, read the relevant skill(s) first. Follow the conventions in each skill — do not deviate without consulting it. Multiple skills may apply to a single change.

| When you touch...                                            | Read these skills first                 |
|--------------------------------------------------------------|-----------------------------------------|
| Any `.rb` file                                               | `/rails-cto-engineer`                   |
| Files in `app/controllers/` (except API)                     | `/rails-cto-restful`                    |
| Files in `app/controllers/api/`                              | `/rails-cto-api`, `/rails-cto-restful`  |
| Files in `app/models/` or `app/commands/` or `app/services/` | `/rails-cto-engineer`                   |
| Files in `app/components/`                                   | `/rails-cto-view-component`             |
| Files in `app/frontend/controllers/` (Stimulus)              | `/rails-cto-stimulus`                   |
| Any `.html.erb` file                                         | `/rails-cto-erb`, `/rails-cto-tailwind` |
| Any `.css` or Tailwind-related file                          | `/rails-cto-tailwind`                   |
| Any test file in `test/`                                     | `/rails-cto-minitest`                   |

## Mandatory: After Modifying Any `.rb` File

Invoke `/rails-cto-qa` and `/rails-cto-security` after every code change. A task is NOT done until QA and security scans pass. Do not skip these even if the user doesn't mention them.

## Mandatory: After Modifying Any `.html.erb` File

Invoke `/rails-cto-erb`, `/rails-cto-tailwind`, and `/rails-cto-security` after every ERB change. A task is NOT done until ERB, Tailwind, and security checks pass. Do not skip these even if the user doesn't mention them.

**Herb is required on every changed ERB file — new or existing.** After modifying any `.html.erb` file, run `bundle exec herb --fix` and `bundle exec herb format` on it. This applies to all ERB files you touch, not just new ones. Review the output and fix any errors or warnings that Herb reports — do not ignore them or move on until they are resolved.

## Mandatory: Every Plan Must Include QA

When creating any implementation plan, invoke `/rails-cto-architect` to structure the plan and read `/rails-cto-engineer` first to understand the project's best practices, conventions, and reusable patterns before proposing new code. Always include `/rails-cto-qa` and `/rails-cto-security` as final steps. No plan is complete without QA and security gates.
