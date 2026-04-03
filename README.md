# fullstack-rails-cto

Opinionated Claude Code plugin for Ruby on Rails development — orchestration, code quality, testing, and git workflows.


## Skills

| Skill                            | Description                                                                      |
|----------------------------------|----------------------------------------------------------------------------------|
| `fullstack-rails-cto`            | Orchestrator — session init, skill routing, QA gates, completion checklist       |
| `fullstack-rails-engineer`       | Core Rails development guidance and patterns                                     |
| `fullstack-rails-api`            | RESTful JSON API conventions and OpenAPI standards                               |
| `fullstack-rails-erb`            | ERB view and partial conventions                                                 |
| `fullstack-rails-minitest`       | Minitest with Spec DSL, parallel tests, SimpleCov coverage                       |
| `fullstack-rails-qa`             | Quality assurance — linting, testing, and code review                            |
| `fullstack-rails-restful`        | RESTful controller and routing patterns                                          |
| `fullstack-rails-stimulus`       | Stimulus controller conventions and Turbo integration                            |
| `fullstack-rails-tailwind`       | Tailwind CSS best practices, design system, dark mode, responsive, accessibility |
| `fullstack-rails-upgrade`        | Rails version upgrade guidance                                                   |
| `fullstack-rails-view-component` | ViewComponent patterns                                                           |
| `fullstack-rails-security`       | Brakeman security scanning — fix high/medium warnings on changed files           |
| `fullstack-rails-commit`         | Stage and commit all changes with human-friendly messages                        |
| `fullstack-rails-pull-request`   | Create PRs targeting staging                                                     |
| `fullstack-rails-production-pr`  | Create production PRs (staging to main)                                          |

### Marketplace Dependencies

These skills reference third-party skills from the Claude Code marketplace:

| Skill                         | Marketplace                                   | Used By                    |
|-------------------------------|-----------------------------------------------|----------------------------|
| `better-stimulus@obie-skills` | [obie/skills](https://github.com/obie/skills) | `fullstack-rails-stimulus` |

## Installation

### Install from the marketplace

```bash
/plugin marketplace add mattsears/fullstack-rails-cto
/plugin install fullstack-rails-cto@fullstack-rails-cto
```

### Install marketplace dependencies

The Stimulus skill depends on `better-stimulus@obie-skills`. Install it from the [obie/skills](https://github.com/obie/skills) marketplace:

```bash
/plugin marketplace add obie/skills
/plugin install better-stimulus@obie-skills
```

### Recommended gems

These gems are used by various skills for linting, formatting, testing, and documentation. Add them to your project's `Gemfile`:

```ruby
# Code quality (used by fullstack-rails-qa, fullstack-rails-cto)
gem "rubocop", require: false
gem "rubocop-rails", require: false
gem "rubocop-minitest", require: false

# Security scanning (used by fullstack-rails-security)
gem "brakeman", require: false

# ERB linting and formatting (used by fullstack-rails-erb)
gem "herb"

# Test coverage (used by fullstack-rails-minitest, fullstack-rails-qa)
group :test do
  gem "simplecov", require: false
  gem "simplecov_json_formatter", require: false
end
```

**Important:** SimpleCov must be configured with the JSON formatter so the QA and Minitest skills can read coverage data. Add this to `test/test_helper.rb` **before** any other requires:

```ruby
require "simplecov"
require "simplecov_json_formatter"

SimpleCov.start("rails") do
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter
  ])
end
```

Without `JSONFormatter`, the skills cannot check test coverage — they rely on `coverage/coverage.json` which is only generated when this formatter is active.

For Herb, also add to `package.json` devDependencies:

```json
"@herb-tools/formatter": "0.9.2",
"@herb-tools/linter": "0.9.2"
```

Then add a `herb.yml` to the root of your project to configure the rewriters:

```yaml
rewriter:
  pre:
    - tailwind-class-sorter
  post:
    - align-attributes
```

The `align-attributes` rewriter is bundled with the ERB skill and will be copied into your project's `.herb/rewriters/` automatically when the skill runs.

For Brakeman, create a `config/brakeman.yml` in your Rails project:

```yaml
---
# Only report high and medium confidence warnings
:min_confidence: 1

# Output format
:output_format: json

# Quiet mode
:quiet: true

# Ignored warning fingerprints (add false positives here)
:ignored_warnings: []
```

The security skill will create this config automatically if missing, but adding it upfront ensures consistent behavior across the team.

None of these are strictly required — each skill gracefully skips its tooling when the gem isn't present. But you'll get the most value with all of them installed.

### Project-level setup (recommended)

Add this to your project's `CLAUDE.md` so the CTO skill kicks in automatically:

```markdown
# Skills

When working on Ruby on Rails projects, always invoke `/fullstack-rails-cto` at the start of a session. It handles skill routing, QA gates, and the completion checklist.

## Mandatory: After Modifying Any `.rb` File

Invoke `/fullstack-rails-qa` after every code change. A task is NOT done until QA passes. Do not skip this even if the user doesn't mention it.

## Mandatory: After Modifying Any `.html.erb` File

Invoke `/fullstack-rails-erb` and `/fullstack-rails-tailwind` after every ERB change. A task is NOT done until ERB and Tailwind checks pass. Do not skip this even if the user doesn't mention it.

## Mandatory: Every Plan Must Include QA

When creating any implementation plan, always include `/fullstack-rails-qa` as a final step. No plan is complete without a QA gate.
```

### Docker Usage

These skills assume Rails runs locally. If you use Docker, add this to your project's `CLAUDE.md`:

```markdown
# Docker

I use Docker for local development. Prefix all Rails, Ruby, bundle, and yarn
commands with `docker compose exec web`. Git and GitHub CLI commands run on
the host — do not prefix those.
```

Adjust `docker compose exec web` to match your service name.

## Updating

```bash
/plugin update fullstack-rails-cto@fullstack-rails-cto
```

## Uninstalling

```bash
/plugin uninstall fullstack-rails-cto@fullstack-rails-cto
```

To also remove the marketplace reference:

```bash
/plugin marketplace remove mattsears/fullstack-rails-cto
```

## Plugin Structure

```
fullstack-rails-cto/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata
├── skills/                   # All skills
│   ├── fullstack-rails-cto/
│   ├── fullstack-rails-engineer/
│   ├── fullstack-rails-api/
│   ├── fullstack-rails-erb/
│   ├── fullstack-rails-minitest/
│   ├── fullstack-rails-qa/
│   ├── fullstack-rails-restful/
│   ├── fullstack-rails-stimulus/
│   ├── fullstack-rails-tailwind/
│   ├── fullstack-rails-upgrade/
│   ├── fullstack-rails-view-component/
│   ├── fullstack-rails-security/
│   ├── fullstack-rails-commit/
│   ├── fullstack-rails-pull-request/
│   └── fullstack-rails-production-pr/
├── claude/
│   └── CLAUDE.md             # Project-level config (for this repo only)
└── README.md
```
