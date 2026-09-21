# rails-cto

Opinionated Claude Code plugin that turns Claude into a senior-engineer-grade Ruby on Rails collaborator. It guides every layer of the stack and enforces strict quality, security, and test gates so nothing ships without review.

## Help wanted — early days

rails-cto is in active early development. The vision is a fully integrated Rails workflow that makes Claude the best collaborator a Ruby on Rails developer can have — see [railscto.com](https://railscto.com) for the bigger picture. There's a lot of ground still to cover, and a helping hand goes a long way. If you write Rails and have opinions about what a senior-engineer-grade Claude should do, contributions, issues, and feedback are all welcome on [GitHub](https://github.com/mattsears/rails-cto/issues).

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

Skills run on whatever model your session is using, so pick a strong one (Fable or Opus) with `/model` for the best results. The one exception is the architect skill, which plans on the best model available to your account for that turn, then hands back to your session model.

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
Then bootstrap the project:

```bash
bundle install
bundle exec rails-cto init
```

### Install marketplace dependencies

The Stimulus skill depends on `better-stimulus@obie-skills`. Install it from the [obie/skills](https://github.com/obie/skills) marketplace:

```bash
/plugin marketplace add obie/skills
/plugin install better-stimulus@obie-skills
```

### Node-side Herb tools

Herb's Node-side formatter and linter aren't part of the gem. Add them to your `package.json` devDependencies:

```json
"@herb-tools/formatter": "0.9.2",
"@herb-tools/linter": "0.9.2"
```

Then run `yarn install` (or `npm install`).

### GitHub CLI

The `rails-cto-pull-request` and `rails-cto-production-pr` skills use the [`gh` CLI](https://cli.github.com/) to open PRs. Install it (`brew install gh` on macOS, or see the install guide for other platforms) and authenticate once:

```bash
gh auth login
```

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
