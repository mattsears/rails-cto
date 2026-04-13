# rails-cto

Opinionated Claude Code plugin for Ruby on Rails development — orchestration, code quality, testing, and git workflows.



## Skills

| Skill                             | Description                                                                          |
|-----------------------------------|--------------------------------------------------------------------------------------|
| `rails-cto`             | Orchestrator — session init, skill routing, QA gates, completion checklist           |
| `rails-cto-engineer`        | Core Rails development guidance and patterns                                         |
| `rails-cto-api`             | RESTful JSON API conventions and OpenAPI standards                                   |
| `rails-cto-erb`             | ERB view and partial conventions                                                     |
| `rails-cto-minitest`        | Minitest with Spec DSL, parallel tests, SimpleCov coverage                           |
| `rails-cto-qa`              | Quality assurance — linting, testing, and code review                                |
| `rails-cto-restful`         | RESTful controller and routing patterns                                              |
| `rails-cto-stimulus`        | Stimulus controller conventions and Turbo integration                                |
| `rails-cto-tailwind`        | Tailwind CSS best practices, design system, dark mode, responsive, accessibility     |
| `rails-cto-upgrade`         | Rails version upgrade guidance                                                       |
| `rails-cto-view-component`  | ViewComponent patterns                                                               |
| `rails-cto-security`        | Security scanning — Brakeman + bundler-audit for code and dependency vulnerabilities |
| `rails-cto-static-analysis` | Static analysis — Reek (code smells), Flog (complexity), Flay (duplication)          |
| `rails-cto-commit`          | Stage and commit all changes with human-friendly messages                            |
| `rails-cto-pull-request`    | Create PRs targeting staging                                                         |
| `rails-cto-production-pr`   | Create production PRs (staging to main)                                              |

### Marketplace Dependencies

These skills reference third-party skills from the Claude Code marketplace:

| Skill                         | Marketplace                                   | Used By                    |
|-------------------------------|-----------------------------------------------|----------------------------|
| `better-stimulus@obie-skills` | [obie/skills](https://github.com/obie/skills) | `rails-cto-stimulus` |

## Installation

### Install from the marketplace

```bash
/plugin marketplace add mattsears/rails-cto
/plugin install rails-cto@rails-cto
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
# Code quality (used by rails-cto-qa, rails-cto)
gem "rubocop", require: false
gem "rubocop-rails", require: false
gem "rubocop-minitest", require: false

# Security scanning (used by rails-cto-security)
gem "brakeman", require: false
gem "bundler-audit", require: false

# Static analysis (used by rails-cto-static-analysis)
gem "reek", require: false
gem "flog", require: false
gem "flay", require: false

# ERB linting and formatting (used by rails-cto-erb)
gem "herb"

# Test coverage (used by rails-cto-minitest, rails-cto-qa)
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

For Reek, the static analysis skill will create a `.reek.yml` with Rails-friendly defaults automatically if one is missing. To customize, add your own `.reek.yml` to the project root. The default config suppresses common Rails patterns (e.g., `TooManyStatements` in migrations, `ControlCouple` in controllers, `IrresponsibleModule` globally) and disables scanning the `test/` directory.

None of these are strictly required — each skill gracefully skips its tooling when the gem isn't present. But you'll get the most value with all of them installed.

### Project-level setup (recommended)

Add this to your project's `CLAUDE.md` so the CTO skill kicks in automatically:

```markdown
# Skills

When working on Ruby on Rails projects, always invoke `/rails-cto` at the start of a session. It handles skill routing, QA gates, and the completion checklist.

## Mandatory: After Modifying Any `.rb` File

Invoke `/rails-cto-qa` after every code change. A task is NOT done until QA passes. Do not skip this even if the user doesn't mention it.

## Mandatory: After Modifying Any `.html.erb` File

Invoke `/rails-cto-erb` and `/rails-cto-tailwind` after every ERB change. A task is NOT done until ERB and Tailwind checks pass. Do not skip this even if the user doesn't mention it.

## Mandatory: Every Plan Must Include QA

When creating any implementation plan, always include `/rails-cto-qa` as a final step. No plan is complete without a QA gate.
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
/plugin update rails-cto@rails-cto
```

## Uninstalling

```bash
/plugin uninstall rails-cto@rails-cto
```

To also remove the marketplace reference:

```bash
/plugin marketplace remove mattsears/rails-cto
```

## Plugin Structure

```
rails-cto/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata
├── skills/                   # All skills
│   ├── rails-cto/
│   ├── rails-cto-engineer/
│   ├── rails-cto-api/
│   ├── rails-cto-erb/
│   ├── rails-cto-minitest/
│   ├── rails-cto-qa/
│   ├── rails-cto-restful/
│   ├── rails-cto-stimulus/
│   ├── rails-cto-tailwind/
│   ├── rails-cto-upgrade/
│   ├── rails-cto-view-component/
│   ├── rails-cto-security/
│   ├── rails-cto-static-analysis/
│   ├── rails-cto-commit/
│   ├── rails-cto-pull-request/
│   └── rails-cto-production-pr/
├── claude/
│   └── CLAUDE.md             # Project-level config (for this repo only)
└── README.md
```
