# rails-cto

Opinionated Claude Code plugin for Ruby on Rails development — orchestration, code quality, testing, and git workflows.

## Companion gem

This plugin has a companion Ruby gem, [`rails-cto`](https://github.com/mattsears/rails-cto-gem), that ships the quality toolchain (RuboCop, Reek, Flog, Flay, Brakeman, bundler-audit, SimpleCov, Herb), the matching config files, a custom RuboCop cop, and the Herb rewriters/rules the skills expect. A single `rails-cto init` command scaffolds everything into a Rails project so the plugin's skills have everything they need to run. See [Installation](#installation) below.


## Skills

Start every session with `/rails-cto` — the orchestrator skill handles session init, routes to specialist skills (engineering, planning, testing, QA, security, git workflows, and more), enforces QA gates, and runs the completion checklist. Browse `skills/` for the full list.

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

### Install marketplace dependencies

The Stimulus skill depends on `better-stimulus@obie-skills`. Install it from the [obie/skills](https://github.com/obie/skills) marketplace:

```bash
/plugin marketplace add obie/skills
/plugin install better-stimulus@obie-skills
```

### Install the companion gem

The plugin's skills rely on a quality toolchain (RuboCop, Reek, Flog, Flay, Brakeman, bundler-audit, SimpleCov, Herb) and a set of matching config files. Rather than installing and configuring all of that by hand, add the companion [`rails-cto` gem](https://github.com/mattsears/rails-cto-gem) to your Rails project:

```ruby
group :development, :test do
  gem "rails-cto"
end
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

Refresh the marketplace manifest first so Claude Code sees the latest published version, then update the plugin:

```bash
/plugin marketplace update rails-cto
/plugin update rails-cto@rails-cto
```

Without the `marketplace update` step, Claude Code keeps using its cached manifest and the plugin update won't pick up new releases.

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
