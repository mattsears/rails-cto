# rails-cto

Opinionated Claude Code plugin that turns Claude into a senior-engineer-grade Ruby on Rails collaborator. It provides expert guidance across the full stack — controllers, models, JSON APIs, ERB, ViewComponents, Stimulus, Tailwind, and Minitest — and enforces a strict quality pipeline on every change, running RuboCop, Reek, Flog, Flay, Brakeman, bundler-audit, and SimpleCov before anything is considered done. It also plans multi-step features, guides Rails version upgrades, and automates the git workflow from clean commits through staging and production pull requests — so no QA step gets silently skipped.

## Skills

rails-cto covers the full Rails development lifecycle:

- Plans multi-step features before code is written — scoping, gem research, edge cases, and step-by-step implementation plans
- Writes idiomatic Rails code for controllers, models, RESTful routes, JSON APIs, and command/service objects
- Builds the front-end with ERB, ViewComponents, Stimulus, Turbo, and Tailwind
- Writes Minitest tests targeting full or near-full coverage — Spec DSL, parallel execution, and SimpleCov reports to verify it
- Auto-formats and lints Ruby with RuboCop and ERB with Herb — fixes what it can, flags what it can't
- Enforces code quality with Reek (code smells), Flog (complexity), and Flay (duplication)
- Scans for security issues using Brakeman and bundler-audit
- Guides Rails version upgrades with selective diffs and upgrade notes
- Automates the git workflow — clean commits, PRs targeting staging, and production release PRs
- Enforces QA gates at every step so nothing ships without tests, lint, and review

Start every session with `/rails-cto` — the orchestrator skill handles session init, routes to specialist skills, enforces QA gates, and runs the completion checklist. Browse `skills/` for the full list of individual skills.

### Marketplace Dependencies

These skills reference third-party skills from the Claude Code marketplace:

| Skill                         | Marketplace                                   | Used By              |
|-------------------------------|-----------------------------------------------|----------------------|
| `better-stimulus@obie-skills` | [obie/skills](https://github.com/obie/skills) | `rails-cto-stimulus` |

## Installation

### Install from the marketplace

```bash
/plugin marketplace add mattsears/rails-cto
/plugin install rails-cto@rails-cto
```
### Install the companion gem

The plugin's skills rely on a quality toolchain (RuboCop, Reek, Flog, Flay, Brakeman, bundler-audit, SimpleCov, Herb) and a set of matching config files. Rather than installing and configuring all of that by hand, add the companion [`rails-cto` gem](https://github.com/mattsears/rails-cto-gem) to your Rails project:

```ruby
group :development, :test do
  gem "rails-cto"
end
```

### Install marketplace dependencies

The Stimulus skill depends on `better-stimulus@obie-skills`. Install it from the [obie/skills](https://github.com/obie/skills) marketplace:

```bash
/plugin marketplace add obie/skills
/plugin install better-stimulus@obie-skills
```

Then bootstrap the project:

```bash
bundle install
bundle exec rails-cto init
```

`rails-cto init` will:

- Pull in the entire quality toolchain as gem dependencies (RuboCop + rubocop-rails + rubocop-minitest, Reek, Flog, Flay, Brakeman, bundler-audit, SimpleCov + simplecov_json_formatter, Herb).
- Drop config templates into your project (skipping any that already exist): `.rubocop.yml`, `.reek.yml`, `.bundler-audit.yml`, `config/brakeman.yml`, `.herb/rewriters/align-attributes.mjs`, `.herb/rules/no-inline-styles.mjs`.
- Patch `test/test_helper.rb` to boot SimpleCov with the JSON formatter (required by the QA and Minitest skills — they read `coverage/coverage.json`).
- Append a short block to your project's `CLAUDE.md` that wires the plugin's mandatory skills (`/rails-cto`, `/rails-cto-qa`, `/rails-cto-erb`, `/rails-cto-tailwind`) into every session.

Pass `--force` to overwrite existing files. Run `bundle exec rails-cto doctor` anytime to verify that every config is present and hasn't drifted from the bundled templates.

### Node-side Herb tools

Herb's Node-side formatter and linter aren't part of the gem. Add them to your `package.json` devDependencies:

```json
"@herb-tools/formatter": "0.9.2",
"@herb-tools/linter": "0.9.2"
```

Then run `yarn install` (or `npm install`).

## Updating

Refresh the marketplace manifest so Claude Code picks up the latest published version:

```bash
/plugin marketplace update rails-cto
```

## Uninstalling

```bash
/plugin uninstall rails-cto@rails-cto
```

To also remove the marketplace reference:

```bash
/plugin marketplace remove mattsears/rails-cto
```
