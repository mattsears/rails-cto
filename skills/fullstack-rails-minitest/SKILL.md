---
name: fullstack-rails-minitest
description: >
  Write and maintain Minitest tests for a Rails 8 application using the Minitest::Spec DSL.
  Covers model tests, command/service tests, controller/integration tests, job tests,
  ViewComponent tests, and system tests. Use this skill whenever writing, fixing, or
  reviewing tests, or when the user asks to add test coverage, write specs, create test
  cases, or debug failing tests. Also trigger when generating new models, controllers,
  commands, jobs, or components that need accompanying tests.
---

# Rails Minitest Skill

This project uses **Minitest::Spec DSL** — not RSpec, not vanilla Minitest::Test. Every test
file follows a consistent structure. Study it before writing anything.

## Pre-flight: Verify SimpleCov JSON Export

Before running any tests, confirm that `test/test_helper.rb` configures SimpleCov to export JSON. Look for `SimpleCov::Formatter::JSONFormatter` in the formatter config. The expected setup is:

```ruby
SimpleCov.start("rails") do

  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter
  ])
end
```

If `JSONFormatter` is missing, add it so that `coverage/coverage.json` is generated when tests run with `COVERAGE=1`. Without this file, the post-test coverage check cannot run. Also verify the `simplecov_json_formatter` gem is in the Gemfile's test group — if not, add it.

## Pre-flight: Scope Changes and Identify Test Gaps

Before writing or running tests, understand what's changed on this branch.

1. **Scope the changes:**
   ```bash
   git diff staging...HEAD --stat
   git diff staging...HEAD --name-only
   ```
   This tells you which files were added or modified. Focus testing efforts on these files only.

2. **Map changed files to test files.** For each changed `.rb` file, find its test counterpart:
   - `app/models/bookmark.rb` → `test/models/bookmark_test.rb`
   - `app/controllers/bookmarks_controller.rb` → `test/controllers/bookmarks_controller_test.rb`
   - `app/commands/bookmarks/create.rb` → `test/commands/bookmarks/create_test.rb`
   - `app/jobs/analyze_bookmark_job.rb` → `test/jobs/analyze_bookmark_job_test.rb`
   - `app/components/forms/combo_select.rb` → `test/components/forms/combo_select_test.rb`

3. **Check for missing tests.** If a changed file has no corresponding test file, create one. New code ships with tests — no exceptions.

4. **Check coverage for existing tests.** Run the tests for the changed files with coverage enabled:
   ```bash
   COVERAGE=1 PARALLEL=1 rails test test/path/to/relevant_test.rb
   ```
   Review the SimpleCov output. If coverage for the changed file is low (methods without test coverage, branches not exercised), add tests to fill the gaps. Prioritize:
   - Public methods with no tests at all
   - Conditional branches (if/else, case/when) that aren't covered
   - Error handling paths
   - Edge cases for newly added logic

5. **For changed JavaScript files**, check if corresponding JS tests exist. If not, create them. Run with `yarn test`.

## Core DSL

Use `describe`, `it`, `let`, `subject`, and `before` blocks. Never use `def test_*` method style.

```ruby
# frozen_string_literal: true

require "test_helper"

class ThingTest < ActiveSupport::TestCase
  let(:account) { Fabricate(:account) }

  subject { account.profile }

  describe "#method_name" do
    it "describes what the method does" do
      assert_equal "expected", subject.method_name
    end
  end
end
```

### Key conventions

- **`let` blocks** — lazy-loaded supporting data (accounts, parent records, config).
  Reserve `let` for dependencies, not the primary object being tested.
- **`before` blocks** — setup that runs before each test in the enclosing `describe`.
- **`describe` blocks** — group by method (`"#instance_method"`, `".class_method"`) or
  behavior (`"when logged in"`, `"with invalid input"`).
- **`it` blocks** — one behavior per test. Name describes the scenario, not the assertion.

### The `subject` Rule (MANDATORY — DO NOT SKIP)

**Every test class MUST define a `subject` block exactly once at the top of the class.** This is non-negotiable. A test file without `subject` is incomplete. Do NOT use `let` for the primary object, do NOT instantiate it inline inside `it` blocks, and do NOT reassign `subject` inside `it` or `describe` blocks.

`subject` is the primary object under test:
- **Model test** → `subject` is an instance of the model
- **Command/service test** → `subject` is an instance of the command's input record
- **Controller test** → `subject` is the authenticated account
- **Job test** → `subject` is the job instance or the record being processed
- **Component test** → `subject` is the component instance

### Varying `subject` across scenarios

When different tests need different attributes on the primary object, use a `let(:attributes)` block that `subject` references. Each nested `describe` overrides `let(:attributes)` to customize for that scenario. **Never reassign `subject` inline.**

```ruby
# CORRECT — subject declared once, variations via let(:attributes)
class PlanDecoratorTest < ActiveSupport::TestCase
  let(:attributes) { {} }

  subject { Fabricate.build(:plan, **attributes) }

  describe "#price_summary" do
    describe "with monthly interval" do
      let(:attributes) { { amount: 1200, interval: "month" } }

      it "returns formatted price" do
        assert_equal "$12.00 / month", subject.price_summary
      end
    end

    describe "with yearly interval" do
      let(:attributes) { { amount: 9600, interval: "year" } }

      it "returns formatted price" do
        assert_equal "$96.00 / year", subject.price_summary
      end
    end

    describe "with zero amount" do
      let(:attributes) { { amount: 0, interval: "month" } }

      it "handles zero" do
        assert_equal "$0.00 / month", subject.price_summary
      end
    end
  end
end
```

```ruby
# WRONG — subject reassigned inline in each test
class PlanDecoratorTest < ActiveSupport::TestCase
  describe "#price_summary" do
    it "returns formatted price with monthly interval" do
      subject = Fabricate.build(:plan, amount: 1200, interval: "month")
      assert_equal "$12.00 / month", subject.price_summary
    end

    it "returns formatted price with yearly interval" do
      subject = Fabricate.build(:plan, amount: 9600, interval: "year")
      assert_equal "$96.00 / year", subject.price_summary
    end
  end
end
```

```ruby
# ALSO WRONG — no subject, object created with a local variable
class BookmarkTest < ActiveSupport::TestCase
  describe "#host" do
    it "returns the host from the URL" do
      bookmark = Fabricate.build(:bookmark, url: "https://example.com/path")
      assert_equal "example.com", bookmark.host
    end
  end
end
```

### When `subject` doesn't need variations

If every test uses the same attributes, define `subject` directly without the `let(:attributes)` pattern:

```ruby
# CORRECT — simple subject, no variations needed
class BookmarkTest < ActiveSupport::TestCase
  let(:account) { Fabricate(:account) }

  subject { Fabricate.build(:bookmark, owner: account, url: "https://example.com/path") }

  describe "#host" do
    it "returns the host from the URL" do
      assert_equal "example.com", subject.host
    end
  end

  describe "#valid?" do
    it "requires a URL" do
      subject.url = nil
      assert_not subject.valid?
    end
  end
end
```

If you are writing a test and have not defined `subject` at the top of the class, stop and add it before continuing.

### Assertions

Use **assert-style** exclusively. Never use `expect(...).to` syntax.

```ruby
assert something                          # truthy
assert_not something                      # falsy
assert_equal expected, actual             # equality
assert_nil value                          # nil check
assert_raises(ErrorClass) { ... }         # exception
assert_difference -> { Model.count }, 1   # count change
assert_no_difference -> { Model.count }   # no change
assert_in_delta expected, actual, 0.0001  # float comparison
assert_match(/pattern/, string)           # regex match
assert_includes collection, item          # inclusion
```

## Test Data

Two systems coexist. **Fabrication** is the primary tool for most tests. **FactoryBot** is
used in controller/integration tests that need accounts with subscriptions.

### Fabrication (preferred)

```ruby
# Simple creation
let(:bookmark) { Fabricate(:bookmark) }

# With overrides
let(:bookmark) { Fabricate(:bookmark, owner: account, title: "Custom") }

# Build without saving
bookmark = Fabricate.build(:bookmark, url: "https://example.com")

# Named variants
Fabricate(:pinned_bookmark)
Fabricate(:account_with_profile)
```

Fabricators live in `test/fabricators/`. Check existing fabricators before creating new ones.

### FactoryBot (for integration tests)

```ruby
let(:account) { create(:account_with_subscriptions) }
```

FactoryBot is included via `FactoryBot::Syntax::Methods` in `ActiveSupport::TestCase`,
so `create`, `build`, and `create_list` are available everywhere.

## Test Types

### Model Tests

Extend `ActiveSupport::TestCase`. Test model methods, validations, callbacks, and scopes.
Always define `subject` as an instance of the model being tested.

```ruby
class BookmarkTest < ActiveSupport::TestCase
  subject { Fabricate.build(:bookmark, url: "https://example.com/path") }

  describe "#host" do
    it "returns the host from the URL" do
      assert_equal "example.com", subject.host
    end
  end
end
```

For callback tests, use `ActiveJob::TestHelper`:

```ruby
describe "callbacks" do
  include ActiveJob::TestHelper

  it "enqueues job when relevant field changes" do
    assert_enqueued_with(job: SomeJob) do
      subject.update!(about: "new value")
    end
  end

  it "does not enqueue job for unrelated changes" do
    subject # ensure record exists
    perform_enqueued_jobs # clear queue

    assert_no_enqueued_jobs(only: SomeJob) do
      subject.update!(name: "New Name")
    end
  end
end
```

### Command / Service Tests

Commands use `.run()` and return result objects with `.success?` / `.failed?`.
Wrap in the command's module namespace.

```ruby
module Bookmarks
  class DestroyTest < ActiveSupport::TestCase
    let(:account) { Fabricate(:account) }

    subject { Fabricate(:bookmark, owner: account) }

    describe "#run" do
      it "permanently deletes the bookmark" do
        bookmark_id = subject.id
        Bookmarks::Destroy.run(bookmark: subject)
        assert_not Bookmark.exists?(bookmark_id)
      end

      it "returns a successful result" do
        result = Bookmarks::Destroy.run(bookmark: subject)
        assert result.success?
      end
    end
  end
end
```

### Controller / Integration Tests

Extend `ActionDispatch::IntegrationTest`. Use `sign_in` helper for authentication.
Test HTTP verbs, response codes, and response body content.

```ruby
class CollectionsControllerTest < ActionDispatch::IntegrationTest
  let(:account) { create(:account_with_subscriptions) }

  before { sign_in(account) }

  describe "GET #index" do
    it "returns a successful response" do
      get collections_path
      assert_response :success
    end
  end

  describe "POST #create" do
    it "creates a new record" do
      assert_difference -> { Collection.count }, 1 do
        post collections_path,
             params: { collection: { title: "New" } },
             as: :turbo_stream
      end
    end

    it "returns success for turbo stream" do
      post collections_path,
           params: { collection: { title: "New" } },
           as: :turbo_stream
      assert_response :success
    end
  end
end
```

**Turbo Stream requests**: pass `as: :turbo_stream` and check `response.body` for
stream element IDs with `assert_match`.

### Job Tests

Can use either `describe JobClass` directly or wrap in a class. Mock dependencies
with Mocha.

```ruby
describe AnalyzeFeedBookmarkJob do
  let(:bookmark) { Fabricate(:bookmark) }
  let(:job) { AnalyzeFeedBookmarkJob.new }

  describe "#perform" do
    it "processes the bookmark" do
      mock_result = mock
      mock_result.expects(:success?).returns(true)
      mock_result.expects(:summary).returns("A summary").at_least_once

      SomeService.expects(:run)
        .with(bookmark: bookmark)
        .returns(mock_result)

      job.perform(bookmark.id)
      bookmark.reload
      assert_equal "A summary", bookmark.summary
    end

    it "raises for missing records" do
      assert_raises(ActiveRecord::RecordNotFound) do
        job.perform(999_999)
      end
    end
  end
end
```

### ViewComponent Tests

Extend `ViewComponent::TestCase`. Use `render_inline` and `assert_selector`.

```ruby
module Forms
  class ComboSelectTest < ViewComponent::TestCase
    describe "Forms::ComboSelect" do
      it "renders with the correct name" do
        render_inline(Forms::ComboSelect.new(url: "/search.json", name: "item[id]"))
        assert_selector "select[name='item[id]']"
      end

      it "sets stimulus controller data attribute" do
        render_inline(Forms::ComboSelect.new(url: "/search.json", name: "item[id]"))
        assert_selector "[data-controller='forms--combo-select']"
      end
    end
  end
end
```

### System Tests

Extend `ApplicationSystemTestCase`. Require `application_system_test_case` (not
`test_helper`). Use Capybara DSL: `visit`, `fill_in`, `click_on`, `assert_selector`.

```ruby
require "application_system_test_case"

class LoginTest < ApplicationSystemTestCase
  let(:profile) { create(:profile) }

  subject { profile.account }

  describe "login" do
    it "signs in with email and password" do
      visit "/login"
      fill_in "login", with: subject.email
      fill_in "password", with: "nopass"
      click_on "Sign in"
      assert_selector "h2", text: "TOP SITES"
    end
  end
end
```

## Mocking with Mocha

Mocha is the mocking library. Key patterns:

```ruby
# Stub a method on any instance
Account.any_instance.stubs(:can_create_collection?).returns(false)

# Expect a method call (fails if not called)
SomeService.expects(:run).with(arg: value).returns(result)

# Expect never called
SomeService.expects(:run).never

# Create a mock object
mock_result = mock
mock_result.expects(:success?).returns(true)

# Stub on a specific instance
job.stubs(:fetch_content).returns("text")
```

## HTTP Stubbing

WebMock is configured globally. The test helper already stubs:
- Meilisearch (`localhost:7700`)
- OpenAI embeddings API (returns 1536-dim zero vector)
- Anthropic Claude API (returns generic text)
- HTTP HEAD requests (returns 200)
- Proxy parser (`localhost:3100`, returns generic page metadata)

For additional HTTP stubs in individual tests:

```ruby
stub_request(:get, "https://api.example.com/data")
  .to_return(status: 200, body: { key: "value" }.to_json,
             headers: { "Content-Type" => "application/json" })
```

## Authentication in Tests

```ruby
# Integration/controller tests — already included
before { sign_in(account) }

# sign_in stubs both current_account and authenticate on ApplicationController
```

## File Organization

```
test/
  models/          # ActiveSupport::TestCase
  commands/        # ActiveSupport::TestCase, namespaced modules
  controllers/     # ActionDispatch::IntegrationTest
  jobs/            # describe JobClass or ActiveSupport::TestCase
  components/      # ViewComponent::TestCase, namespaced modules
  system/          # ApplicationSystemTestCase
  fabricators/     # Fabrication definitions
  factories/       # FactoryBot definitions
  test_helper.rb   # Global config, stubs, helpers
```

## Running Tests

Always run tests in parallel with code coverage enabled:

```bash
COVERAGE=1 PARALLEL=1 rails test                              # Full suite
COVERAGE=1 PARALLEL=1 rails test test/models/bookmark_test.rb # Single file
COVERAGE=1 PARALLEL=1 rails test -n "test_method_name"        # Single test by name
```

### JavaScript Tests

After modifying any JavaScript or Stimulus controller, also run the JS test suite:

```bash
yarn test
```

Run both Ruby and JavaScript tests when changes span both languages:

```bash
COVERAGE=1 PARALLEL=1 rails test && yarn test
```

## Post-Test Coverage Check

After running tests with `COVERAGE=1`, check for `coverage/coverage.json` in the project root. If it exists, read it to verify your tests adequately cover the code you changed.

### How to check

1. **Read the coverage file:**
   ```bash
   cat coverage/coverage.json
   ```
   The file is a JSON object keyed by absolute file path. Each entry contains a `lines` array where:
   - `null` = line not relevant (comments, blank lines, `end` keywords)
   - `0` = executable line **not covered** by any test
   - `1+` = line covered (the number is how many times it was executed)

2. **Filter to changed files only.** Look up each `.rb` file you created or modified in this session. Ignore files you didn't touch.

3. **Calculate coverage for each file:**
   - Count relevant lines (non-`null` entries)
   - Count covered lines (entries `>= 1`)
   - Coverage % = covered / relevant × 100

4. **Evaluate against thresholds:**
   - **≥ 90%** — Good. Move on.
   - **70–89%** — Review the uncovered lines. If they're meaningful code paths (conditionals, error handling, public methods), write additional tests to cover them.
   - **< 70%** — Insufficient. Identify all uncovered methods and branches, then add tests until coverage reaches at least 90%.

5. **Focus on what matters.** Prioritize covering:
   - Public methods with zero coverage
   - Conditional branches (`if`/`else`, `case`/`when`) where only one path is hit
   - Error handling and rescue blocks
   - Guard clauses and early returns

If `coverage/coverage.json` does not exist, the project may not have SimpleCov configured. In that case, skip this check and rely on the manual test review in the pre-flight section.

## Principles

1. **Test behavior, not implementation** — assert on outcomes, not internal method calls
   (unless verifying side effects like job enqueues or service calls).
2. **Keep tests focused** — aim for one assertion per test when practical, and never
   exceed 4 assert statements in a single `it` block. If you need more, split into
   separate tests. This keeps failures easy to diagnose and test names meaningful.
3. **Descriptive test names** — `it "returns the host from a standard URL"` not
   `it "works"`.
4. **Minimal setup** — only fabricate what the test needs. Prefer `Fabricate.build` when
   persistence isn't required.
5. **No flaky tests** — avoid time-dependent assertions without freezing time. Use
   `assert_in_delta` for ranges.
6. **Follow existing patterns** — before writing a new test file, read 2-3 similar ones
   in the same directory.
7. **Never skip tests** — do not use `skip`, `skip_if`, or comment out test blocks. If a
   test is failing, fix the code or the test — don't skip it. Skipped tests create blind
   spots that hide real bugs.
