---
name: fullstack-rails-security
description: >
  Run Brakeman security scans on changed files and fix high/medium confidence warnings.
  Use when any .rb or .html.erb file is created or modified. Also use when the user
  mentions "security", "brakeman", "vulnerability", "XSS", "SQL injection",
  "mass assignment", "CSRF", or asks about secure coding practices.
  Proactively invoke this skill after code changes, even if the user doesn't ask.
---

# Security Scanning in This Project

Every `.rb` and `.html.erb` change is scanned with [Brakeman](https://github.com/presidentbeef/brakeman) before the work is considered done. High and medium confidence warnings must be fixed. This skill runs **after** code changes are made — it is a post-change quality gate, not a write blocker.

## Pre-flight: Check Brakeman Setup (MANDATORY)

**You MUST run these steps every time this skill is invoked.**

### 1. Check if Brakeman is available

```bash
bundle exec brakeman --version 2>/dev/null
```

If the command fails, inform the user:

> "This project doesn't have the `brakeman` gem installed. Add it to your Gemfile:
>
> ```ruby
> group :development do
>   gem "brakeman", require: false
> end
> ```
>
> Then run `bundle install`."

If Brakeman is not available, skip the scanning steps below and continue. Do not block on Brakeman installation. But if Brakeman IS available, you MUST run the scanning steps — do not skip them.

### 2. Install the recommended config (if missing)

Check if the project already has a Brakeman config:

```bash
ls config/brakeman.yml 2>/dev/null
```

If the file does not exist, create it:

```yaml
---
# Brakeman configuration
# See https://brakemanscanner.org/docs/options/ for all options

# Only report high and medium confidence warnings
:min_confidence: 1

# Output format (overridden by CLI flags, but serves as default)
:output_format: json

# Quiet mode — suppress informational messages
:quiet: true

# Ignored warning fingerprints (add false positives here)
:ignored_warnings: []
```

### 3. Identify changed files

Use git to find only the `.rb` and `.html.erb` files that were modified:

```bash
git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null | grep -E '\.(rb|html\.erb)$'
```

If there are unstaged changes too:

```bash
git diff --name-only --diff-filter=ACMR 2>/dev/null | grep -E '\.(rb|html\.erb)$'
```

Combine both lists and deduplicate. If no matching files were changed, skip the scan — there is nothing to check.

### 4. Run Brakeman on changed files

Run Brakeman scoped to only the changed files, outputting JSON to stdout:

```bash
bundle exec brakeman --only-files file1.rb,file2.rb -f json -q --no-pager
```

For example, if `app/controllers/users_controller.rb` and `app/models/user.rb` were changed:

```bash
bundle exec brakeman --only-files app/controllers/users_controller.rb,app/models/user.rb -f json -q --no-pager
```

**Important:** Pass file paths as a comma-separated list to `--only-files`. Use relative paths from the Rails root.

---

## Reading Brakeman JSON Output

The JSON output contains a `warnings` array. Each warning has:

```json
{
  "warning_type": "SQL Injection",
  "warning_code": 0,
  "message": "Possible SQL injection",
  "file": "app/controllers/users_controller.rb",
  "line": 42,
  "code": "User.where(params[:query])",
  "confidence": "High",
  "fingerprint": "abc123..."
}
```

Key fields:
- `confidence` — "High", "Medium", or "Weak"
- `warning_type` — Category (SQL Injection, Cross-Site Scripting, Mass Assignment, etc.)
- `file` and `line` — Exact location of the issue
- `code` — The vulnerable code snippet
- `fingerprint` — Unique identifier (used for ignoring false positives)

---

## Fixing Warnings

### High and Medium confidence: fix immediately

For each high or medium confidence warning:

1. Read the warning's `file`, `line`, `code`, and `message`
2. Fix the underlying vulnerability — do not suppress or ignore it
3. Common fixes by warning type:

| Warning Type | Typical Fix |
|---|---|
| SQL Injection | Use parameterized queries, `where(field: value)`, or `sanitize_sql` |
| Cross-Site Scripting (XSS) | Use `sanitize`, `h()`, or `content_tag` instead of `raw`/`html_safe` |
| Mass Assignment | Use `strong_parameters` — never `permit!` |
| Command Injection | Use `Open3.capture3` or array form of `system` instead of backticks/`exec` |
| Dynamic Render Path | Use explicit template names, not user-controlled paths |
| File Access | Validate and sanitize file paths, use `ActiveStorage` |
| Redirect | Use `_path`/`_url` helpers, validate redirect targets with `url_from` |
| Unsafe Deserialization | Avoid `Marshal.load`, `YAML.unsafe_load` on user input |
| Session Manipulation | Use `reset_session`, don't store sensitive data in sessions |
| Dangerous Send | Validate method names against an allowlist before `.send` |

### Weak confidence: mention but do not fix

For weak confidence warnings, list them once as informational:

> "Brakeman also reported N weak-confidence warnings that may be false positives:
> - [file:line] warning_type: message
>
> These are informational only — review them if you'd like, but no action is required."

Do not attempt to fix weak warnings. Do not block completion on them.

### False positives

If a warning's fingerprint is listed in `config/brakeman.yml` under `:ignored_warnings`, skip it silently. Do not mention ignored warnings in the output.

---

## Verify Fixes

After fixing all high and medium warnings, re-run Brakeman on the same files:

```bash
bundle exec brakeman --only-files file1.rb,file2.rb -f json -q --no-pager
```

- If all high/medium warnings are resolved: the scan passes. Continue.
- If warnings remain after one fix attempt: **stop and report the remaining warnings to the user.** Do not attempt a second fix cycle. List each remaining warning with its file, line, type, and message so the user can decide how to proceed.

---

## Integration with QA

This skill runs alongside `/fullstack-rails-qa`, not as a replacement. The typical end-of-task flow is:

1. `/fullstack-rails-qa` — RuboCop linting + test suite
2. `/fullstack-rails-security` — Brakeman security scan
3. Fix any issues from either skill
4. Task complete

Both must pass before the work is considered done.
