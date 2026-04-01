---
name: fullstack-rails-stimulus
description: >
  How to write Stimulus controllers for this Rails 8 / Hotwire project.
  Use when creating, modifying, or debugging Stimulus controllers,
  wiring controllers to ERB views, or integrating JavaScript behavior
  with Turbo Streams and Frames. Also use when the user mentions
  "stimulus", "controller", "data-action", "data-controller",
  "targets", "values", or asks about frontend interactivity.
---

# Stimulus Controllers in This Project

## Reuse First, Create Second

Before writing a new controller, search the existing controllers in `app/frontend/controllers/` and `app/components/` for one that already does what you need. Many behaviors are already covered — autosave, clipboard, redirect, sortable, hover toggling, reset form, and more live in `utils/`. Check `index.js` for the full inventory.

If no existing controller fits, design the new one for **general-purpose reuse**. Controllers should not be tightly coupled to a single view or feature. Keep behavior generic and configurable through values, targets, and action parameters so the same controller can be wired into different contexts without duplication. Place broadly reusable controllers in `utils/`; only use domain namespaces (`bookmarks/`, `feeds/`) when the behavior is truly domain-specific.

### NEVER create single-purpose controllers

Every Stimulus controller must be designed to work across multiple views and contexts. Ask: "Could another page need this same behavior?" If yes — and the answer is almost always yes — name and design it generically.

**Name controllers after the behavior, not the feature:**

| Task | WRONG (single-purpose) | RIGHT (reusable) |
|---|---|---|
| Save form when checkbox toggled | `bookmark_auto_check_controller.js` | `toggle_submit_controller.js` |
| Dismiss a flash message | `flash_close_controller.js` | `dismissable_controller.js` |
| Copy text to clipboard on click | `share_link_copy_controller.js` | `clipboard_controller.js` |
| Show/hide a section | `settings_panel_toggle_controller.js` | `toggle_element_controller.js` |
| Submit form on input change | `search_auto_submit_controller.js` | `auto_submit_controller.js` |
| Confirm before destructive action | `delete_bookmark_confirm_controller.js` | `confirm_action_controller.js` |

**Drive specifics through values and targets, not hard-coded selectors:**

```js
// WRONG — hard-coded to one specific form
export default class extends Controller {
  save() {
    document.querySelector("#bookmark-settings-form").requestSubmit();
  }
}

// RIGHT — works with any form via targets
export default class extends Controller {
  static targets = ["form"];

  save() {
    this.formTarget.requestSubmit();
  }
}
```

If you find yourself including a feature name (bookmark, user, feed, setting) in the controller filename, stop and rethink. The controller is probably too specific.

## File Layout

```
app/frontend/controllers/
├── index.js                        # All registrations live here
├── application_controller.js       # Minimal base class
├── utils.js                        # Shared helper functions
├── transition.js                   # Reusable enter/leave transitions
│
├── <name>_controller.js            # Root-level controllers
├── bookmarks/                      # Domain-namespaced controllers
├── users/
├── accounts/
├── stripe/
└── utils/                          # Small, reusable utility controllers

app/components/**/                  # ViewComponent controllers live with their components
```

## Registration

Every controller is manually imported and registered in `index.js`.
There is no auto-loading — each new controller needs two lines added here.

```js
// app/frontend/controllers/index.js
import AutosaveController from "./utils/autosave_controller";
application.register("utils--autosave", AutosaveController);
```

**Naming rules for the identifier string:**

| Controller location | Identifier pattern | Example |
|---|---|---|
| `utils/autosave_controller.js` | `utils--autosave` | Double-dash separates namespace |
| `bookmarks/list_reorder_controller.js` | `bookmarks--list-reorder` | Underscores become hyphens |
| `reader_controller.js` (root) | `reader` | No namespace prefix |
| `app/components/overlays/modal_controller.js` | `overlays--modal` | Components use their directory |

## Controller Structure

Follow this order inside every controller. See `app/frontend/controllers/utils/autosave_controller.js` as a compact reference:

```js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {

  // 1. Static declarations — always at the top
  static targets = ["form", "submit"];
  static values  = { delay: Number, refreshInterval: Number };
  static outlets = [];   // only if needed
  static classes = [];   // only if needed

  // 2. Lifecycle hooks
  connect() {
    this.timeout = null;
    this.duration = this.hasDelayValue ? this.delayValue : 1500;
  }

  disconnect() {
    // Clean up listeners, timers, intervals
  }

  // 3. Public action methods (called from data-action)
  save() { /* ... */ }
  submit() { /* ... */ }

  // 4. Private helpers (use # prefix)
  #processResponse(html) { /* ... */ }

  // 5. Private getters
  get #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content;
  }
}
```

**Key conventions:**
- Always `import { Controller } from "@hotwired/stimulus"` — not ApplicationController, unless you specifically need its behavior
- Use `export default class extends Controller` (anonymous class)
- Declare `static targets`, `static values`, etc. even if empty arrays aren't needed — only declare what you use
- Use `hasXTarget` / `hasXValue` guards before accessing optional targets/values
- Document every public method with a JSDoc comment describing **why** it exists, not what it does:

```js
/**
 * Debounces form submissions to prevent duplicate saves
 * when the user rapidly edits fields in the autosave form.
 */
save() { /* ... */ }
```

## Wiring in ERB Views

```erb
<%# Controller + values %>
<div data-controller="utils--autosave"
     data-utils--autosave-delay-value="2000">

  <%# Targets %>
  <form data-utils--autosave-target="form">

    <%# Actions — format: event->identifier#method %>
    <input data-action="input->utils--autosave#save">

    <button data-utils--autosave-target="submit">Save</button>
  </form>
</div>
```

**Multiple controllers on one element** — space-separated:

```erb
<div data-controller="hover-toggler app--bookmark">
```

## Values

Declare with types. Stimulus coerces automatically.

```js
static values = {
  url: String,
  delay: Number,
  open: Boolean,
  items: Array,
  config: Object,
  // With defaults:
  duration: { type: Number, default: 300 }
};
```

Use the `*ValueChanged()` callback to react to changes:

```js
openValueChanged() {
  this.applyVisibility();
}
```

## Cross-Controller Communication

**Outlets** — direct access to another controller instance:

```js
static outlets = ["reader"];

summarize() {
  this.readerOutlet.iframeTarget.classList.add("hidden");
}
```

```erb
<div data-controller="reader-summary"
     data-reader-summary-reader-outlet="#reader-frame">
```

**Custom events** — loose coupling via document:

```js
// Dispatch
document.dispatchEvent(new CustomEvent("bookmark:drag-start", { detail: { id } }));

// Listen (bind in connect, remove in disconnect)
connect() {
  this.onDragStart = this.#handleDragStart.bind(this);
  document.addEventListener("bookmark:drag-start", this.onDragStart);
}

disconnect() {
  document.removeEventListener("bookmark:drag-start", this.onDragStart);
}
```

## Turbo Integration

**Rendering Turbo Streams from JS:**

```js
const response = await fetch(url, {
  method: "PATCH",
  headers: {
    "Accept": "text/vnd.turbo-stream.html",
    "X-CSRF-Token": this.#csrfToken
  }
});
const html = await response.text();
Turbo.renderStreamMessage(html);
```

**Turbo Frame navigation:**

```js
this.frameTarget.src = newUrl;
```

**Listening to Turbo events:**

```js
document.addEventListener("turbo:before-stream-render", this.#boundBeforeRender);
document.addEventListener("turbo:frame-load", () => { /* ... */ });
```

## Cleanup

Always clean up in `disconnect()` to prevent memory leaks:

```js
disconnect() {
  clearTimeout(this.timeout);
  clearInterval(this.interval);
  document.removeEventListener("keydown", this.boundKeyHandler);
}
```

When binding listeners manually, store the bound reference so you can remove it:

```js
connect() {
  this.boundKeyHandler = this.#handleKey.bind(this);
  document.addEventListener("keydown", this.boundKeyHandler);
}
```

## CSRF Token Pattern

Every controller that makes fetch requests uses this getter:

```js
get #csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content;
}
```

## Error Handling

Use try-catch for fetch calls; fail silently for non-critical browser APIs:

```js
async #loadContent() {
  try {
    const response = await fetch(this.urlValue);
    if (!response.ok) throw new Error("Network response was not ok");
    const html = await response.text();
    this.contentTarget.innerHTML = html;
  } catch (error) {
    console.error("Failed to load content:", error);
  }
}
```

## Animation Helpers

The project provides `transition.js` for enter/leave animations:

```js
import { transition } from "../transition";

async toggle() {
  await transition(this.panelTarget, this.openValue);
}
```

For frame-perfect DOM updates, use double-rAF:

```js
requestAnimationFrame(() => {
  requestAnimationFrame(() => {
    // DOM is fully painted before this runs
  });
});
```

## Pre-flight: Verify Vitest Setup

Before writing or running Stimulus controller tests, confirm the project has Vitest configured.

1. **Check for Vitest in package.json:**
   ```bash
   grep -q '"vitest"' package.json && echo "vitest installed" || echo "vitest missing"
   ```

2. **Check for a Vitest config file** — look for `vitest.config.js`, `vitest.config.ts`, or a `test` section in `vite.config.js`:
   ```bash
   ls vitest.config.* vite.config.* 2>/dev/null
   ```

3. **Check the test script exists:**
   ```bash
   grep '"test"' package.json
   ```

If Vitest is not installed or configured, inform the user:

> "This project doesn't have Vitest set up for JavaScript tests. To enable Stimulus controller testing, add these to your project:
>
> ```bash
> yarn add -D vitest @testing-library/dom jsdom
> ```
>
> **vitest.config.js:**
> ```js
> import { defineConfig } from "vitest/config";
>
> export default defineConfig({
>   test: {
>     environment: "jsdom",
>     globals: true,
>   },
> });
> ```
>
> **package.json** (add to scripts):
> ```json
> "test": "vitest run"
> ```
>
> Then run `yarn install`."

If Vitest is not available, skip the testing sections below but still flag that tests are missing.

## Testing Stimulus Controllers

Every new or modified Stimulus controller must have a corresponding test file. Map by convention:

- `app/frontend/controllers/utils/autosave_controller.js` → `test/javascript/utils/autosave_controller.test.js`
- `app/frontend/controllers/bookmarks/list_reorder_controller.js` → `test/javascript/bookmarks/list_reorder_controller.test.js`
- `app/frontend/controllers/reader_controller.js` → `test/javascript/reader_controller.test.js`
- `app/components/overlays/modal_controller.js` → `test/javascript/components/overlays/modal_controller.test.js`

If the test file does not exist, create it.

### Test structure

```js
import { Application } from "@hotwired/stimulus";
import AutosaveController from "controllers/utils/autosave_controller";

describe("AutosaveController", () => {
  let application;

  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="utils--autosave"
           data-utils--autosave-delay-value="500">
        <form data-utils--autosave-target="form">
          <input data-action="input->utils--autosave#save" />
          <button data-utils--autosave-target="submit">Save</button>
        </form>
      </div>
    `;

    application = Application.start();
    application.register("utils--autosave", AutosaveController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = "";
  });

  it("connects the controller", () => {
    const element = document.querySelector("[data-controller='utils--autosave']");
    expect(element).not.toBeNull();
  });

  it("sets the delay value from the attribute", () => {
    const controller = application.getControllerForElementAndIdentifier(
      document.querySelector("[data-controller='utils--autosave']"),
      "utils--autosave"
    );
    expect(controller.delayValue).toBe(500);
  });
});
```

### What to test

- **connect/disconnect** — controller initializes state, cleans up timers/listeners
- **Values** — default values are set, `*ValueChanged` callbacks fire
- **Targets** — elements are found, missing targets are handled gracefully
- **Actions** — public methods respond correctly to simulated events
- **Fetch calls** — mock `fetch` and verify correct URL, method, headers, and response handling
- **DOM updates** — verify the controller modifies the DOM as expected

### Running tests

```bash
yarn test                                    # Full JS test suite
yarn test test/javascript/utils/autosave_controller.test.js  # Single file
```

Always run `yarn test` after modifying any Stimulus controller. Tests must pass before the work is considered done.

## Marketplace Reference

When working on Stimulus controllers, also invoke `/better-stimulus@obie-skills` for additional best practices and patterns from [betterstimulus.com](https://betterstimulus.com). This skill complements the project-specific conventions above with broader community patterns for writing clean, maintainable Stimulus code.

## Checklist for New Controllers

1. **Search existing controllers first** — check `utils/`, `app/components/`, and `index.js` for something reusable
2. Design for reuse — keep behavior generic, drive specifics through values and targets
3. Create `app/frontend/controllers/<namespace>/<name>_controller.js`
4. Add import + `application.register()` to `index.js`
5. Use the identifier in your ERB with `data-controller="namespace--name"`
6. Declare only the static properties you actually use
7. Clean up timers, intervals, and listeners in `disconnect()`
8. Use `#private` methods for internal logic
9. Prefer `data-action` in HTML over manual `addEventListener` when possible
10. **Write tests** — create a corresponding `.test.js` file and run `yarn test`
