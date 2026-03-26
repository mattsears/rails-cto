---
name: fullstack-rails-qa
description: >
  Quality assurance for Ruby on Rails projects — linting, testing, and code review.
  Use after creating or modifying any Ruby file — controllers, models, commands,
  services, jobs, tests, or any other .rb file. Proactively run this whenever
  Ruby files are touched, even if the user doesn't explicitly ask for it.
  Also use when the user mentions "rubocop", "lint", "style", "autocorrect",
  "code quality", "code review", "QA", or "review my code".
---

# Quality Assurance

Every Ruby file must pass three gates before it's considered done: **linting**, **testing**, and **code review**. These aren't separate steps you do later — they're part of writing the code.

## Workflow

### 1. Pre-flight

Before reviewing anything, understand what's being shipped.

1. **Check the current branch and determine the base branch:**
   ```bash
   git branch --show-current
   ```
   - If on `main`, stop: "You're on main — run QA from a feature branch or staging."
   - If on `staging`, the base branch is `main`.
   - If on any other branch (feature branch), the base branch is `staging`.

2. **Check working tree status:** Run `git status` (never use `-uall`). Uncommitted changes are included in the review — no need to ask.
3. **Scope the changes to this branch only:**
   ```bash
   git diff <base>...HEAD --stat
   git log <base>..HEAD --oneline
   ```
   Replace `<base>` with the base branch determined in step 1. This is what's about to be shipped. The rest of the QA workflow applies only to these files and changes — not the entire codebase.
4. **Check review readiness:** If there are no changes relative to the base branch, there's nothing to review. Let the user know and stop.

### 2. Write or modify Ruby code

Make your changes to controllers, models, commands, tests, etc.

### 3. Verify test coverage exists

For each changed `.rb` file (excluding test files themselves), check that a corresponding test file exists. Map by convention:

- `app/models/bookmark.rb` → `test/models/bookmark_test.rb`
- `app/controllers/bookmarks_controller.rb` → `test/controllers/bookmarks_controller_test.rb`
- `app/commands/bookmarks/create.rb` → `test/commands/bookmarks/create_test.rb`
- `app/services/bookmarks/search.rb` → `test/services/bookmarks/search_test.rb`
- `app/jobs/sync_bookmark_job.rb` → `test/jobs/sync_bookmark_job_test.rb`
- `app/components/forms/combo_select.rb` → `test/components/forms/combo_select_test.rb`

If the test file does not exist, create it before proceeding. Invoke `/fullstack-rails-minitest` for the correct test structure and DSL. New or changed code without tests is not shippable.

**Every test file MUST define a `subject` block.** If a test file exists but has no `subject`, add one before running the tests. `subject` declares the primary object under test — without it, the test structure is incomplete. See the code review section below for correct vs wrong examples.

### 4. Run RuboCop with autocorrect

```bash
bundle exec rubocop -A path/to/changed_file.rb
```

Always use `-A` (aggressive autocorrect) so RuboCop fixes everything it can automatically. Run it on each changed Ruby file — not the entire codebase.

For multiple files changed at once:

```bash
bundle exec rubocop -A app/controllers/bookmarks_controller.rb app/models/bookmark.rb test/controllers/bookmarks_controller_test.rb
```

Review the output for:
- **Offenses that couldn't be auto-corrected** — these need manual fixes
- **Unexpected changes** — autocorrect occasionally alters logic (rare but possible)

If RuboCop reports remaining offenses after `-A`, fix them manually and re-run.

### 5. Run tests

After RuboCop passes, run the tests for the files you changed in parallel with coverage enabled:

```bash
COVERAGE=1 PARALLEL=1 bundle exec rails test test/path/to/relevant_test.rb
```

If you changed a model, run its model test. If you changed a controller, run its controller test. If you're unsure which tests cover your change, run the full suite:

```bash
COVERAGE=1 PARALLEL=1 bundle exec rails test
```

### 6. Check code coverage

After tests pass, check for `coverage/coverage.json` in the project root. If it exists, read it to verify your tests adequately cover the changed code.

1. **Read the file** — It's a JSON object keyed by absolute file path. Each entry has a `lines` array: `null` = not relevant, `0` = uncovered, `1+` = covered.
2. **Filter to changed files only** — Look up each `.rb` file you created or modified. Ignore files you didn't touch.
3. **Calculate coverage** — For each file: coverage % = covered lines (≥ 1) / relevant lines (non-null) × 100.
4. **Evaluate:**
   - **≥ 90%** — Good. Move on.
   - **70–89%** — Review uncovered lines. If they're meaningful (conditionals, error handling, public methods), add tests.
   - **< 70%** — Insufficient. Add tests until coverage reaches at least 90%.
5. **Prioritize** — Public methods with zero coverage, conditional branches where only one path is hit, rescue blocks, and guard clauses.

If `coverage/coverage.json` does not exist, skip this step.

### 7. Code review

After linting and tests pass, review the changed code against these quality checks. This is where you catch the things that automated tools miss.

#### DRY check and dead code removal

Look for repeated logic across the changed files and nearby code. If you see the same pattern three or more times, it probably belongs in a shared method, concern, or service object. Two similar lines are fine — three is a signal.

Also look for dead code — methods, variables, or constants that are no longer called or referenced anywhere. If code is no longer used, remove it. Don't leave commented-out code or orphaned methods behind.

**Example:**
```ruby
# Repeated in multiple controllers — extract to a concern or helper
current_user.bookmarks.where(active: true).order(created_at: :desc)
```

#### Test structure: `subject` is required

Every test class must define a `subject` block that returns the primary object under test. If reviewing a test file and `subject` is missing, add it. The `subject` makes it immediately clear what the test is exercising and prevents re-instantiating the primary object inline across `it` blocks.

```ruby
# WRONG — no subject, object created inline
class BookmarkTest < ActiveSupport::TestCase
  describe "#host" do
    it "returns the host" do
      bookmark = Fabricate.build(:bookmark, url: "https://example.com/path")
      assert_equal "example.com", bookmark.host
    end
  end
end

# RIGHT — subject declares the primary object
class BookmarkTest < ActiveSupport::TestCase
  subject { Fabricate.build(:bookmark, url: "https://example.com/path") }

  describe "#host" do
    it "returns the host" do
      assert_equal "example.com", subject.host
    end
  end
end
```

#### Edge cases and error handling

For each changed method, think about what happens when things go wrong:
- What if a record is `nil`?
- What if a collection is empty?
- What if an external service times out or returns an error?
- What if the user provides unexpected input?

Favor explicit handling over silent failures. A user should see a clear error message rather than a broken page or missing data. Handle errors at the boundaries — where user input enters the system and where external services are called.

**Example:**
```ruby
# FRAGILE — blows up if bookmark is nil
bookmark.tags.pluck(:name)

# BETTER — handles the nil case
bookmark&.tags&.pluck(:name) || []
```

#### Performance review

Check for common Rails performance pitfalls in the changed code:

- **N+1 queries** — If a view or method iterates over a collection and accesses an association, make sure it's eager-loaded with `includes`, `preload`, or `eager_load`.
- **Unnecessary queries** — Could this use `exists?` instead of `count > 0`? Could this use `pluck` instead of loading full records?
- **Missing database indexes** — If you added a `where` clause on a column or a new foreign key, check that the column is indexed.
- **Heavy work in requests** — Long-running tasks (API calls, file processing, email sending) belong in background jobs, not controller actions.

**Example:**
```ruby
# N+1 — each bookmark loads its tags separately
@bookmarks = Bookmark.all
@bookmarks.each { |b| b.tags.map(&:name) }

# FIXED — eager load the association
@bookmarks = Bookmark.includes(:tags).all
```

#### Documentation check

Every method and function in changed `.rb`, `.rake`, and `.js` files must have a comment directly above the declaration describing **why** it exists — not what it does (the code shows that). Focus on intent, context, or the business reason. This applies to all methods, not just new ones — if an existing method in a changed file is missing a comment, add one.

Scan each changed file for `def` (Ruby/Rake) or `function`/method declarations (JS) and verify a comment appears on the line(s) immediately above. If any are missing, add them before moving on.

**Ruby / Rake (`.rb`, `.rake`)** — plain comment above `def`:

```ruby
# Ensures the user sees their most relevant bookmarks first,
# because recently active tags reflect current interests.
def prioritized_bookmarks
  bookmarks.joins(:tags).order("tags.updated_at DESC")
end
```

**JavaScript (`.js`)** — JSDoc above the function or method:

```js
/**
 * Debounces save requests to avoid overwhelming the server
 * when the user types quickly in the autosave form.
 */
save() { /* ... */ }
```

**Exceptions** — skip comments for trivial/framework-conventional methods where the intent is self-evident: `initialize` with simple assignment, single-line delegation (`delegate :name, to: :user`), accessor-style methods (`def name = @name`), and standard Rails callbacks that are already named descriptively (`before_save :normalize_email`).

#### Debug statement cleanup

Remove any `console.log`, `Rails.logger.debug`, `puts`, `pp`, `p`, or `binding.pry` statements that were added during development. These should never ship to staging or production.

#### No inline variables in ERB

Scan any changed `.html.erb` files for inline variable assignments (`<% variable = ... %>`). The only acceptable assignment in ERB is `local_assigns.fetch` for partial local defaults. Everything else is untestable and must be moved out.

```erb
<%# WRONG — not testable %>
<% tags = bookmark.tags.active.order(:name) %>
<% show_banner = current_account.trial? && current_account.days_remaining < 7 %>
<% display_name = "#{user.first_name} #{user.last_name}".strip %>

<%# RIGHT — testable in controller/model tests %>
<%= render partial: "tag", collection: @tags %>
<%= render "shared/trial_banner" if @show_trial_banner %>
<%= current_account.display_name %>
```

Move violations to:
- **Data/queries** → controller instance variable
- **Formatting/display** → model method or helper
- **Conditional flags** → controller boolean
- **Computed values** → model method or concern

#### RuboCop compliance

Do not modify `.rubocop.yml` to suppress or work around warnings. If RuboCop flags something, fix the code — don't change the rules. Do not add `rubocop:disable` comments as a workaround.

#### Clarity check

Code should be explicit over clever. When reviewing, ask:
- Would someone unfamiliar with this codebase understand what this code does?
- Are variable and method names descriptive enough?
- Is there a simpler way to express the same logic?
- Are any comments near the changed code now stale or misleading? Stale comments are worse than no comments — update or remove them.

#### Failure mode thinking

For each new code path or integration point, consider one realistic way it could fail in production (timeout, nil reference, race condition, stale data) and whether:
1. A test covers that failure
2. Error handling exists for it
3. The user would see a clear error or a silent failure

If a failure would be silent — no test, no error handling, no user feedback — flag it. Silent failures are the hardest bugs to find later.

## Project Configuration

This project uses `rubocop-rails-omakase` as its base with these overrides:

- **Max line length**: 100 characters
- **Frozen string literal comment**: Required on every `.rb` file
- **Ordered gems**: Gemfile entries must be alphabetically sorted

## Common RuboCop Issues

### Frozen string literal comment

Every Ruby file must start with this comment:

```ruby
# frozen_string_literal: true
```

### Line length (100 chars max)

Break long lines with string continuation or method chaining:

```ruby
# WRONG — over 100 characters
Rails.logger.error "Failed to update embedding for tag #{tag_id}: #{result.errors.message_list.join(', ')}"

# RIGHT — split with continuation
Rails.logger.error "Failed to update embedding for tag #{tag_id}: " \
                   "#{result.errors.message_list.join(', ')}"
```

### Array bracket spacing

```ruby
# WRONG
["title", "full_title"]

# RIGHT — rubocop-rails-omakase uses brackets with spaces
[ "title", "full_title" ]
```

### Hash style

```ruby
# WRONG
{ :key => "value" }

# RIGHT
{ key: "value" }
```

## Quick Reference

| Step | Command |
|------|---------|
| Autocorrect a file | `bundle exec rubocop -A path/to/file.rb` |
| Autocorrect multiple files | `bundle exec rubocop -A file1.rb file2.rb` |
| Check without fixing | `bundle exec rubocop path/to/file.rb` |
| Run related tests | `PARALLEL=1 COVERAGE=1 bundle exec rails test test/path/to/test.rb` |
| Run full test suite | `PARALLEL=1 COVERAGE=1 bundle exec rails test` |
