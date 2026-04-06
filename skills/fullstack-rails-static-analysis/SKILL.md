---
name: fullstack-rails-static-analysis
description: >
  Run Reek, Flog, and Flay static analysis on changed Ruby files and auto-refactor
  when issues are found. Use after modifying any .rb file. Also use when the user
  mentions "reek", "flog", "flay", "code smells", "complexity", "duplication",
  "static analysis", or "refactor". Proactively invoke this skill after code changes,
  even if the user doesn't ask.
---

# Static Analysis (Reek, Flog, Flay)

Every `.rb` change is analyzed with Reek, Flog, and Flay before the work is considered done. Code smells are fixed, complex methods are refactored, and duplication is eliminated. This skill runs before RuboCop and tests — refactor first, then lint and verify.

## Pre-flight

### Check tool availability

Before running any analysis, verify each tool is installed. Run all three checks:

```bash
bundle exec reek --version 2>/dev/null
bundle exec flog --version 2>/dev/null
bundle exec flay --version 2>/dev/null
```

If a tool is **not available**, print this message and skip that tool's steps (but continue with the others):

> `[tool]` is not installed. Add it to your Gemfile under `:development`:
>
> ```ruby
> gem "[tool]", require: false
> ```
>
> Then run `bundle install`.

If **none** of the three tools are available, stop and inform the user that static analysis cannot run.

### Install `.reek.yml` if missing

Check for a Reek configuration file:

```bash
ls .reek.yml 2>/dev/null
```

If `.reek.yml` does not exist, create it with the Rails-friendly defaults from the **Configuration** section below. If it already exists, leave it as-is.

### Identify changed files

Collect all `.rb` files that have been created or modified:

```bash
git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null | grep -E '\.rb$' | sort -u
git diff --name-only --diff-filter=ACMR 2>/dev/null | grep -E '\.rb$' | sort -u
```

Combine and deduplicate both lists. If no `.rb` files changed, skip all scans and report "No Ruby files changed — static analysis skipped."

## Step 1: Reek — Code Smell Detection

Run Reek on each changed file individually:

```bash
bundle exec reek path/to/changed_file.rb
```

For multiple changed files:

```bash
bundle exec reek app/models/user.rb app/commands/users/create.rb app/controllers/users_controller.rb
```

### Interpreting Reek output

Reek reports warnings in this format:

```
app/models/user.rb -- 2 warnings:
  [4]:UncommunicativeMethodName: User#x has the name 'x'
  [12]:TooManyStatements: User#process has approx 15 statements
```

Use this table to decide what to fix and how:

| Smell | When it's real | Auto-fix |
|-------|---------------|----------|
| `TooManyStatements` | > 10 statements in a non-migration method | Extract into private methods or a service/command object |
| `LongParameterList` | > 4 parameters | Introduce keyword arguments or a parameter object |
| `FeatureEnvy` | Method uses another object's data more than its own | Move the method to the object it references most |
| `DataClump` | 3+ methods share the same parameter group | Extract a value object |
| `DuplicateMethodCall` | Same call appears 3+ times in one method | Extract to a local variable |
| `UncommunicativeVariableName` | Single-letter or cryptic names | Rename to something descriptive |
| `UncommunicativeMethodName` | Single-letter or cryptic names | Rename to something descriptive |
| `NilCheck` | Explicit `nil?` checks | Fix only if it masks a real nil-safety issue — often noise in Rails |
| `UtilityFunction` | Method doesn't use `self` | Fix in models and services; ignore in helpers and decorators |
| `TooManyInstanceVariables` | > 6 instance variables in a class | Extract a value object or split responsibilities |
| `TooManyMethods` | > 20 methods in a class | Extract concerns or split into smaller classes |
| `ControlCouple` | Method behavior depends on a boolean/flag arg | Replace with two methods or use polymorphism — ignore in controllers |
| `BooleanParameter` | `def method(flag = true)` | Replace with two methods — ignore in controllers and helpers |

### Auto-fix rules

- For each Reek warning, apply the fix from the table above.
- **Refactor silently** when the fix is internal (Extract Method, rename, extract local variable).
- **Ask the user first** if the fix would rename a public method, change a method signature, or move a method to a different class.
- After fixing, re-run Reek on the file to verify the smell is gone.

## Step 2: Flog — Complexity Measurement

Run Flog on each changed file individually:

```bash
bundle exec flog path/to/changed_file.rb
```

### Interpreting Flog output

Flog outputs a pain score per method, sorted by complexity:

```
    47.2: User#process          app/models/user.rb:12-45
    18.3: User#validate_email   app/models/user.rb:50-62
     6.1: User#name             app/models/user.rb:8-10
```

Higher scores mean more complex, harder-to-maintain code.

| Score | Verdict | Action |
|-------|---------|--------|
| ≤ 10 | Trivial | No action needed |
| 11–25 | Acceptable | No action needed |
| 26–60 | Too complex | **Must refactor** — extract methods, simplify conditionals, reduce nesting |
| > 60 | Severe | **Stop and refactor immediately** — this method is a maintenance hazard |

### Auto-fix for high Flog scores

For methods scoring above 25:

1. **Identify complexity drivers** — nested conditionals, long method chains, multiple responsibilities, deeply nested blocks.
2. **Apply Extract Method** — pull cohesive blocks into private methods with descriptive names.
3. **Simplify conditionals** — replace nested `if/else` with guard clauses, early returns, or `case` statements.
4. **Split responsibilities** — if a method does more than one thing, extract a command or service object.
5. **Re-run Flog** to verify the score dropped below 25.

If the score remains above 25 after one refactoring pass, report the method and its score to the user and move on.

## Step 3: Flay — Duplication Detection

Flay identifies structural similarities in code, ignoring surface-level differences like variable names, literal values, and whitespace.

### Determine scan scope

For each changed `.rb` file, collect its sibling files:

1. Identify the parent directory of the changed file (e.g., `app/models/` for `app/models/user.rb`).
2. Collect all `.rb` files in that directory.
3. If the directory contains more than 20 `.rb` files, limit to the changed file plus the 10 most recently modified siblings:
   ```bash
   ls -t app/models/*.rb | head -10
   ```
4. If only one `.rb` file exists in the directory, skip Flay for that file — duplication detection requires at least two files.

### Run Flay

```bash
bundle exec flay app/models/*.rb
```

Or with a specific set of files:

```bash
bundle exec flay app/models/user.rb app/models/account.rb app/models/profile.rb
```

### Interpreting Flay output

Flay reports structural duplication with a mass score:

```
1) IDENTICAL code found in :defn (mass = 72)
  app/models/user.rb:15
  app/models/account.rb:22

2) Similar code found in :defn (mass = 32)
  app/controllers/users_controller.rb:10
  app/controllers/accounts_controller.rb:12
```

| Mass | Verdict | Action |
|------|---------|--------|
| < 16 | Insignificant | No action needed |
| 16–50 | Moderate duplication | Extract shared logic into a concern, module, or shared method |
| > 50 | Significant duplication | **Must extract** — this is copy-paste code that will drift |

### Auto-fix for duplication

For nodes with mass ≥ 16:

1. **Read both locations** — understand the duplicated structure.
2. **Choose an extraction target:**
   - Models → shared concern in `app/models/concerns/`
   - Controllers → controller concern in `app/controllers/concerns/`
   - Commands/services → shared module or base class
   - Same file → private method
3. **Extract the shared logic** into the chosen target.
4. **Include the concern or module** in both original locations.
5. **Re-run Flay** to verify the mass dropped below 16.

If the duplication spans fundamentally different contexts where extraction would be forced or artificial, report it to the user instead of extracting.

## Verify and summarize

After all three tools have run and fixes have been applied:

1. **Re-run all three tools** on the changed files to confirm fixes took effect.
2. **Produce a brief summary:**

```
**Static Analysis Summary**
- Reek: N smells found, N fixed, N remaining
- Flog: N methods above threshold (25), N refactored
- Flay: N duplications (mass ≥ 16), N extracted
- Status: PASS / NEEDS ATTENTION
```

**PASS** means all issues were resolved or no issues were found. **NEEDS ATTENTION** means some issues remain that require manual intervention — list them with file, line, and description.

## Configuration

### `.reek.yml` — Rails-friendly defaults

If the project has no `.reek.yml`, create this file in the project root:

```yaml
---
# Rails-friendly Reek configuration
# Generated by fullstack-rails-static-analysis

detectors:
  IrresponsibleModule:
    enabled: false
  InstanceVariableAssumption:
    enabled: false
  TooManyStatements:
    max_statements: 10
  ControlCouple:
    exclude:
      - !ruby/regexp /app\/controllers/
  BooleanParameter:
    exclude:
      - !ruby/regexp /app\/controllers/
      - !ruby/regexp /app\/helpers/
  FeatureEnvy:
    exclude:
      - !ruby/regexp /app\/helpers/
      - !ruby/regexp /app\/decorators/
  UtilityFunction:
    exclude:
      - !ruby/regexp /app\/helpers/
      - !ruby/regexp /app\/decorators/
  UncommunicativeMethodName:
    accept:
      - e
      - t
      - q
      - x
      - y
  LongParameterList:
    max_params: 4
  TooManyInstanceVariables:
    max_instance_variables: 6
  TooManyMethods:
    max_methods: 20

directories:
  "test":
    enabled: false
  "db/migrate":
    TooManyStatements:
      enabled: false
    FeatureEnvy:
      enabled: false
```

### Thresholds summary

| Tool | Metric | Threshold | Action |
|------|--------|-----------|--------|
| Reek | Code smell | Any warning | Auto-fix per interpretation table |
| Flog | Method complexity | > 25 per method | Must refactor |
| Flog | Severe complexity | > 60 per method | Stop and refactor immediately |
| Flay | Structural duplication | Mass ≥ 16 | Extract shared logic |

## Quick Reference

| Task | Command |
|------|---------|
| Scan one file for smells | `bundle exec reek path/to/file.rb` |
| Scan one file for complexity | `bundle exec flog path/to/file.rb` |
| Scan directory for duplication | `bundle exec flay path/to/dir/*.rb` |
| Scan specific files for duplication | `bundle exec flay file1.rb file2.rb` |
