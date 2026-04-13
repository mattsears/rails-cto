---
name: rails-cto-erb
description: >
  How to write clean, well-formatted ERB templates for this Rails 8 project.
  Use when creating or modifying any ERB view, partial, layout, or component template.
  Also use when the user mentions "erb", "views", "partials", "templates",
  "html formatting", "attribute alignment", or asks about view-layer code.
  Proactively apply these rules whenever touching .html.erb files, even if
  the user doesn't explicitly ask for formatting help.
---

# ERB Templates in This Project

ERB files are the most-read files in the codebase. Developers scan them constantly to understand layout, wiring, and data flow. Every formatting decision should optimize for scannability — a developer glancing at a file should immediately see the structure, the Stimulus wiring, and the data being rendered.

## The Golden Rules

1. **No logic in templates.** ERB files render — they do not compute, query, or decide.
2. **Align attributes vertically.** Multi-attribute elements get one attribute per line.
3. **Indent consistently at 2 spaces.** No tabs, no 4-space blocks.
4. **Comment sections, not lines.** Use `<%# ... %>` to label logical groups.

---

## Pre-flight: Lint and Format ERB Files (MANDATORY)

**You MUST run these steps every time this skill is invoked.** After modifying any `.html.erb` file, run the Herb linter and formatter on the changed files. Herb catches syntax issues and enforces consistent formatting that manual review can miss.

### 1. Check if Herb is available

```bash
bundle exec herb --version 2>/dev/null
```

If the command fails, inform the user:

> "This project doesn't have the `herb` gem installed. For enhanced ERB linting and formatting, add these to your project:
>
> **Gemfile:**
> ```ruby
> gem "herb"
> ```
>
> **package.json (devDependencies):**
> ```json
> "@herb-tools/formatter": "0.9.2",
> "@herb-tools/linter": "0.9.2"
> ```
>
> Then run `bundle install && yarn install`."

If Herb is not available, skip steps 2, 3, and 4 below and continue with the rest of the ERB skill. Do not block on Herb installation. But if Herb IS available, you MUST run steps 2, 3, and 4 — do not skip them.

### 2. Install bundled rewriters and rules (if missing)

Check if the project already has the attribute alignment rewriter and the no-inline-styles rule:

```bash
ls .herb/rewriters/align-attributes.mjs 2>/dev/null
ls .herb/rules/no-inline-styles.mjs 2>/dev/null
```

If either file does not exist, copy it from this skill's templates:

```bash
mkdir -p .herb/rewriters .herb/rules
cp templates/align-attributes.mjs .herb/rewriters/
cp templates/no-inline-styles.mjs .herb/rules/
```

Bundled with this skill:
- [templates/align-attributes.mjs](templates/align-attributes.mjs) — vertically aligns HTML attributes when an element has two or more
- [templates/no-inline-styles.mjs](templates/no-inline-styles.mjs) — flags `style="..."` attributes and enforces Tailwind utility classes instead

### 3. Identify changed ERB files

Use git to find only the `.erb` files that were modified, not the entire codebase:

```bash
git diff --name-only --diff-filter=ACMR HEAD | grep '\.erb$'
```

If there are unstaged changes too:

```bash
git diff --name-only --diff-filter=ACMR | grep '\.erb$'
```

### 4. Run Herb on changed files

For each changed `.erb` file, run the linter with auto-fix first, then the formatter:

```bash
bundle exec herb --fix path/to/changed_file.html.erb
bundle exec herb format path/to/changed_file.html.erb
```

For multiple files:

```bash
bundle exec herb --fix app/views/bookmarks/index.html.erb app/views/bookmarks/_bookmark.html.erb
bundle exec herb format app/views/bookmarks/index.html.erb app/views/bookmarks/_bookmark.html.erb
```

Review the output for any issues that couldn't be auto-fixed — these need manual attention. **Fix ALL warnings in the file, not just ones you introduced.** If Herb reports pre-existing issues unrelated to your changes, fix them anyway. Every file you touch should be left with zero Herb warnings.

---

## Attribute Alignment

When an HTML element has more than one attribute, break each attribute onto its own line. Align attributes with the first attribute after the tag name:

```erb
<%# CORRECT — attributes aligned vertically %>
<div class="pane-field-group"
     data-controller="bookmarks--tag-sync"
     data-bookmarks--tag-sync-url-value="<%= sync_bookmark_taggings_path(bookmark) %>"
     data-action="forms--combo-select:change->bookmarks--tag-sync#sync">
```

```erb
<%# WRONG — everything crammed on one line %>
<div class="pane-field-group" data-controller="bookmarks--tag-sync" data-bookmarks--tag-sync-url-value="<%= sync_bookmark_taggings_path(bookmark) %>" data-action="forms--combo-select:change->bookmarks--tag-sync#sync">
```

A single-attribute element can stay on one line:

```erb
<div class="flex-1 px-6 py-6 space-y-5">
```

### Render calls

For ViewComponent and partial renders with multiple arguments, align parameters with the opening parenthesis:

```erb
<%= render(Forms::EditableField.new(model: bookmark,
                                    field_type: :text,
                                    attribute: :title,
                                    url: bookmark_url,
                                    field_arguments: { class: "text-base font-medium" })) %>
```

For `form_with` and similar helpers:

```erb
<%= form_with(model: bookmark, method: :patch,
              class: "space-y-5",
              data: { controller: "utils--autosave" }) do |f| %>
```

### Buttons and interactive elements

```erb
<button type="button"
        class="inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs"
        data-action="click->combo-suggestions#add"
        data-id="<%= item.id %>"
        data-name="<%= item.name %>"
        title="Add tag">
  <%= item.name %>
</button>
```

### `<input>` and form fields

```erb
<input type="file"
       accept="image/*"
       data-avatar-upload-target="input"
       data-action="change->avatar-upload#selectFile"
       class="hidden">
```

---

## No Logic in ERB

ERB files should contain **zero** business logic, calculations, or variable declarations beyond `local_assigns.fetch` defaults.

### Why: Testability

Inline variables in ERB are **not testable**. You cannot unit-test a local variable assigned inside a template. When logic lives in a controller (instance variable), model method, or helper, it can be tested independently with Minitest. This is the primary reason inline variables are banned — if it can't be tested, it shouldn't be in ERB.

### What belongs in ERB

- Rendering components and partials
- Iterating over collections passed from the controller
- Simple conditionals that control visibility (`if @items.any?`)
- Reading locals via `local_assigns.fetch`
- Output helpers (`link_to`, `image_tag`, `icon`, `t()`)

### What does NOT belong in ERB

Move these to controllers, concerns, helpers, or model methods — where they can be tested.

**Inline variable assignments (NEVER):**

Any `<% variable = ... %>` line in ERB (other than `local_assigns.fetch`) is wrong. It doesn't matter how simple the assignment is — if it's not a partial local default, it belongs in the controller or a helper.

```erb
<%# WRONG — inline variables are not testable %>
<% tags = bookmark.tags.where(account_id: current_account.id).order(:name) %>
<% bookmark_count = current_account.bookmarks.count %>
<% suggested = Tag.where(category: :interest).limit(8) %>
<% display_name = "#{user.first_name} #{user.last_name}".strip %>
<% show_banner = current_account.trial? && current_account.days_remaining < 7 %>

<%# RIGHT — instance variables from the controller, testable in controller tests %>
<%= render partial: "tag", collection: @tags %>
<%= @bookmark_count %>
<%= current_account.display_name %>
<%= render "shared/trial_banner" if @show_trial_banner %>
```

When you see an inline variable in ERB, move it:
- **Data/queries** → controller sets an instance variable (`@tags`, `@bookmark_count`)
- **Formatting/display** → model method (`user.display_name`) or helper (`format_count(total)`)
- **Conditional flags** → controller sets a boolean instance variable (`@show_trial_banner`)
- **Computed values** → model method or concern (`account.days_remaining_display`)

**Math and calculations:**

```erb
<%# WRONG — arithmetic in the template, inline styles %>
<span><%= (bookmark.reading_time / 60.0).ceil %> min read</span>
<span><%= ((completed.to_f / total) * 100).round %>% complete</span>
<div style="width: <%= (tag.taggings_count.to_f / max_count * 100).round %>%">

<%# RIGHT — computed in controller or model, Tailwind classes instead of inline styles %>
<span><%= bookmark.reading_time_display %></span>
<span><%= @completion_percentage %>% complete</span>
<div class="<%= tag.weight_class %>">
```

**Database queries:**

```erb
<%# WRONG — querying in the template %>
<% recent_tags = Tag.where(account_id: current_account.id).order(updated_at: :desc).limit(5) %>

<%# RIGHT — queried in controller, passed to view %>
<% @recent_tags.each do |tag| %>
```

**String manipulation and formatting:**

```erb
<%# WRONG — formatting logic in the template %>
<span><%= bookmark.url.gsub(/^https?:\/\//, '').truncate(40) %></span>

<%# RIGHT — use a helper or model method %>
<span><%= bookmark.display_url %></span>
```

### Acceptable local defaults

The one exception is reading partial locals with defaults at the top of a partial:

```erb
<%# This is fine — declaring expected locals with fallback values %>
<% context = local_assigns.fetch(:context, nil) %>
<% active_tab = local_assigns.fetch(:active_tab, :read) %>
<% extra_attrs ||= {} %>
```

Keep these at the very top of the file, right after the header comment.

---

## No Inline Styles

Never use `style="..."` attributes in ERB templates. Use Tailwind CSS utility classes instead. Inline styles bypass the design system, can't be purged, don't support responsive or dark mode variants, and make templates harder to scan.

The bundled `no-inline-styles.mjs` Herb rule flags these automatically during the lint step.

```erb
<%# WRONG — inline styles %>
<div style="display: flex; gap: 8px; padding: 16px;">
<div style="width: 50%">
<span style="color: red; font-weight: bold;">Error</span>
<div style="margin-top: 1rem; border-bottom: 1px solid #e5e7eb;">

<%# RIGHT — Tailwind utility classes %>
<div class="flex gap-2 p-4">
<div class="w-1/2">
<span class="text-red-600 font-bold">Error</span>
<div class="mt-4 border-b border-gray-200 dark:border-gray-700">
```

**Dynamic widths and computed values** — when the width depends on data (e.g., progress bars), use a model method that returns a Tailwind class:

```erb
<%# WRONG — inline style for dynamic width %>
<div style="width: <%= @progress %>%">

<%# RIGHT — model returns a Tailwind class like "w-1/4", "w-1/2", "w-3/4", "w-full" %>
<div class="<%= @progress_width_class %>">
```

If the value truly cannot map to a Tailwind class (e.g., pixel-precise positioning from user data), extract it to a ViewComponent or helper that encapsulates the style — never put it inline in a template.

---

## File Structure

Every ERB partial follows this structure:

```erb
<%# Path comment and description of what this partial does %>
<%# Additional notes about accepted locals if needed %>
<% local_defaults = local_assigns.fetch(:local_defaults, nil) %>

<%# Section Label %>
<div class="...">
  <%# Subsection Label %>
  <div class="...">
    <%= render SomeComponent.new(...) %>
  </div>
</div>
```

1. **Header comment** — file path and/or description of purpose
2. **Local defaults** — `local_assigns.fetch` calls (if any)
3. **Markup** — organized into labeled sections

### Documenting partials

For partials that accept locals, document them in the header:

```erb
<%# Shared split-pane layout for reading-pane controller.
    Locals:
      frame_id    — turbo frame ID for the reader pane
      extra_attrs — optional hash of extra data attributes
    Block: rendered as list pane content
%>
<% extra_attrs ||= {} %>
```

---

## HTML Formatting

### Indentation

Always 2 spaces. Nested elements increase indentation by one level:

```erb
<div class="outer">
  <div class="inner">
    <span class="text"><%= @value %></span>
  </div>
</div>
```

### Conditionals

Indent content inside `<% if %>` blocks:

```erb
<% if @bookmark.feed.present? %>
  <div class="pane-field-group">
    <label class="pane-field-label">Source</label>
    <div class="flex items-center gap-2">
      <%= inline_icon(:lucide_rss, "w-4 h-4") %>
      <span class="truncate"><%= @bookmark.feed.name %></span>
    </div>
  </div>
<% end %>
```

### Iterators

```erb
<div class="flex flex-wrap gap-2">
  <% @tags.each do |tag| %>
    <span class="tag-chip"><%= tag.name %></span>
  <% end %>
</div>
```

### Long Tailwind class strings

Keep classes on the same line as `class=` unless the line exceeds ~100 characters. When wrapping, keep the continuation on the next line indented under the opening quote:

```erb
<%# Single line — fits comfortably %>
<div class="flex items-center gap-2 px-3 py-2 rounded-lg">

<%# Wrapped — long class list %>
<button class="inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-medium
               bg-violet-50 text-violet-700 dark:bg-violet-900/30 dark:text-violet-300
               hover:bg-violet-100 dark:hover:bg-violet-900/50 transition-colors cursor-pointer"
        data-action="click->combo-suggestions#add">
```

### Closing tags

`<% end %>` aligns with its opening `<% if %>`, `<% each %>`, or `<%= form_with %>`:

```erb
<%= form_with(model: @bookmark) do |f| %>
  <%= f.text_field :title %>
<% end %>
```

---

## ERB Comments

Use `<%# ... %>` for comments. Place them immediately before the element or section they describe:

```erb
<%# Title (editable) %>
<div class="pane-field-group">

<%# Collection %>
<%= form_with(model: bookmark) do |f| %>
```

Use multi-line ERB comments for file headers and documentation:

```erb
<%# Shared split-pane layout for reading-pane controller.
    Locals:
      frame_id    — turbo frame ID
      extra_attrs — optional hash of extra data attributes
    Block: rendered as list pane content
%>
```

Avoid HTML comments (`<!-- -->`) for documentation — they leak into the rendered output. Use them only for IE conditionals or legacy compatibility.

---

## Stimulus Wiring in ERB

Data attributes for Stimulus should follow the same vertical alignment rules. Group them logically: controller first, then values, then targets, then actions:

```erb
<div class="pane-field-group"
     data-controller="collections--combo-select-create"
     data-collections--combo-select-create-create-url-value="<%= collections_path(format: :json) %>"
     data-collections--combo-select-create-search-url-value="<%= search_collections_path %>"
     data-action="forms--combo-select:change->utils--autosave#save">
```

Order: `class` first, then `data-controller`, then `data-*-value`, then `data-*-target`, then `data-action`, then `id`/`title`/other attributes.

---

## Turbo Frames and Streams

```erb
<%= turbo_frame_tag frame_id,
                    data: { reading_pane_target: "readerFrame" } do %>
<% end %>
```

```erb
<%= turbo_stream.replace dom_id(@bookmark) do %>
  <%= render partial: "bookmarks/bookmark",
             locals: { bookmark: @bookmark } %>
<% end %>
```

---

## Light Mode and Dark Mode

Every UI change must look correct in both light mode and dark mode. When adding or modifying Tailwind classes, always include the `dark:` variant for colors, backgrounds, borders, and text:

```erb
<%# WRONG — only light mode %>
<div class="bg-white text-gray-900 border-gray-200">

<%# RIGHT — both modes %>
<div class="bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100 border-gray-200 dark:border-gray-700">
```

After making view changes, visually verify the UI in both modes before considering the work done.

## Shared Partials

Avoid duplicating markup across views. If the same UI pattern appears in more than one place, extract it into a shared partial under `app/views/shared/` or a ViewComponent. Before creating a new partial, check if one already exists that does what you need.

```erb
<%# WRONG — same card markup copy-pasted in index.html.erb and show.html.erb %>

<%# RIGHT — extract to a shared partial %>
<%= render partial: "bookmarks/bookmark_card", locals: { bookmark: bookmark } %>
```

## Quick Reference: Do vs Don't

| Do | Don't |
|---|---|
| Set `@suggested_tags` in the controller | Query `Tag.where(...)` in ERB |
| Use `bookmark.reading_time_display` | Write `(bookmark.reading_time / 60.0).ceil` in ERB |
| Align attributes vertically | Cram 4+ attributes on one line |
| Use `<%# ... %>` for comments | Use `<!-- -->` for documentation |
| Put local defaults at top of partial | Scatter variable assignments throughout |
| Use `local_assigns.fetch(:key, default)` | Use complex ternaries for defaults |
| Pass data as locals or instance vars | Compute derived values inline |
| Use Tailwind classes for all styling | Use `style="..."` inline attributes |
