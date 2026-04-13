---
name: rails-cto-tailwind
description: >
  How to write clean, maintainable Tailwind CSS in Rails projects.
  Use when creating or modifying any .html.erb file, view, partial, layout,
  ViewComponent template, or stylesheet that involves Tailwind classes.
  Proactively apply these rules whenever touching .html.erb files, even if
  the user doesn't explicitly ask about styling — ERB files almost always
  contain Tailwind classes. Also use when the user mentions "tailwind", "css",
  "styling", "dark mode", "responsive", "design system", "colors", "spacing",
  "class soup", "@apply", or asks about making something look good, fixing layout,
  or working with the UI.
---

# Tailwind CSS in This Project

Tailwind is the only styling system in this project. No plain CSS, no inline `style` attributes, no external CSS frameworks. Every visual decision flows through Tailwind utilities and the design tokens defined in `tailwind.config.js`.

The two prerequisites for Tailwind to work well at scale are a **design system with consistent tokens** and a **component-based architecture**. This skill enforces both.

## The Golden Rules

1. **No plain CSS.** All styling goes through Tailwind utilities or `@apply` in component layers. Never write raw CSS properties.
2. **No inline styles.** Never use the `style` attribute on HTML elements. If Tailwind doesn't have a utility for it, extend the config.
3. **Reuse components first.** Before adding classes to a new element, check if an existing partial, ViewComponent, or shared pattern already handles it.
4. **Design tokens over magic numbers.** Use colors, spacing, and sizes from `tailwind.config.js` — not arbitrary values like `bg-[#3b82f6]` or `p-[13px]`.
5. **Every UI works in light and dark mode.** No exceptions.
6. **Every UI is responsive.** No exceptions.

---

## Design System: Theme Configuration

The single source of truth for all visual decisions is `tailwind.config.js`. When you need a color, spacing value, or breakpoint, it comes from here — not from arbitrary values scattered across templates.

### Semantic color naming

Name colors by their purpose, not their appearance. This makes it easy to update the palette without hunting through every template.

```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: { ... },     // Brand / main actions
        secondary: { ... },   // Supporting / secondary actions
        accent: { ... },      // Highlights and emphasis
        success: { ... },     // Positive feedback
        warning: { ... },     // Cautionary feedback
        error: { ... },       // Error states
        surface: { ... },     // Backgrounds and cards
        muted: { ... },       // Subdued text and borders
      }
    }
  }
}
```

Use these semantic names in templates: `bg-primary-500`, `text-error-600`, `border-muted-200`. Never use raw hex codes or arbitrary color values.

### Consistent spacing

Define a spacing scale and stick to it. Tailwind's default scale (0, 1, 2, 3, 4, 5, 6, 8, 10, 12, ...) is solid — extend it only when you have a clear reason.

```erb
<%# WRONG — arbitrary spacing breaks visual rhythm %>
<div class="p-[13px] mt-[7px] gap-[22px]">

<%# RIGHT — use the scale %>
<div class="p-3 mt-2 gap-5">
```

If you genuinely need a custom spacing value, add it to the config rather than using arbitrary values:

```js
spacing: {
  '18': '4.5rem',  // Added because the card grid needs this specific gap
}
```

---

## Reducing Class Bloat

Long strings of utility classes — "class soup" — make templates hard to read and maintain. The goal is to keep class lists short, scannable, and intentional.

### Use shorthand utilities

Tailwind provides combined utilities. Use them instead of spelling out each direction:

```erb
<%# WRONG — verbose %>
<div class="pt-4 pb-4 pl-6 pr-6">

<%# RIGHT — shorthand %>
<div class="py-4 px-6">
```

### Drop default values

Don't include classes that duplicate CSS defaults:

```erb
<%# WRONG — flex-row is the default %>
<div class="flex flex-row justify-between">

<%# RIGHT — flex already implies row direction %>
<div class="flex justify-between">
```

### Keep class order consistent

Follow a consistent order so developers can scan classes predictably. Use the official Prettier plugin for Tailwind CSS to automate this:

**Layout → Sizing → Spacing → Typography → Colors → Effects → States**

```erb
<%# Sorted: layout, sizing, spacing, colors, effects, states %>
<button class="flex items-center h-10 px-4 bg-primary-500 text-white rounded-lg shadow-sm hover:bg-primary-600 focus:ring-2">
```

Install the Prettier plugin if the project doesn't have it:

```json
// .prettierrc or package.json
{
  "plugins": ["prettier-plugin-tailwindcss"]
}
```

---

## Component-First Architecture

The primary weapon against class soup is **extracting components**, not `@apply`. When you see the same cluster of classes repeated across multiple templates, extract it into a partial or ViewComponent — not a CSS abstraction.

### Extract to partials and ViewComponents

```erb
<%# WRONG — same button classes copy-pasted everywhere %>
<button class="inline-flex items-center gap-2 px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 focus:ring-2 focus:ring-primary-300 dark:bg-primary-600 dark:hover:bg-primary-700">
  Save
</button>

<%# RIGHT — extract to a component %>
<%= render ButtonComponent.new(variant: :primary, label: "Save") %>
```

### Use variants for component flexibility

Define a finite set of variants rather than accepting arbitrary classes. This keeps the design system consistent:

```ruby
# app/components/button_component.rb
VARIANTS = {
  primary: "bg-primary-500 text-white hover:bg-primary-600 dark:bg-primary-600 dark:hover:bg-primary-700",
  secondary: "bg-surface-100 text-surface-800 hover:bg-surface-200 dark:bg-surface-700 dark:text-surface-100",
  danger: "bg-error-500 text-white hover:bg-error-600 dark:bg-error-600 dark:hover:bg-error-700"
}.freeze
```

Changes to a variant propagate everywhere that variant is used — one place to update, not dozens.

### When to use `@apply`

Reserve `@apply` for cases where component extraction isn't practical — global base styles, third-party library overrides, or elements generated by gems you don't control:

```css
/* app/frontend/stylesheets/application.css */
@layer components {
  /* Base styles for elements you can't wrap in a component */
  .prose-content a {
    @apply text-primary-600 underline hover:text-primary-800 dark:text-primary-400;
  }

  /* Third-party gem output that you can't add classes to directly */
  .trix-content h2 {
    @apply text-lg font-semibold mt-6 mb-2;
  }
}
```

Use `@layer components` to keep `@apply` rules organized and avoid specificity issues. If you can extract a ViewComponent or partial instead, always prefer that.

---

## Dark Mode

Every element with color-related classes needs a `dark:` variant. Dark mode is not an afterthought — it ships with the initial implementation.

### Always pair light and dark

```erb
<%# WRONG — dark mode forgotten %>
<div class="bg-white text-gray-900 border-gray-200">

<%# RIGHT — both modes %>
<div class="bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100 border-gray-200 dark:border-gray-700">
```

### Color contrast matters

Dark mode isn't just inverting colors. Maintain WCAG AA contrast ratios (4.5:1 for normal text, 3:1 for large text):

- Light text on dark backgrounds: use `-100` or `-200` shades
- Dark text on light backgrounds: use `-800` or `-900` shades
- Avoid pure white (`#fff`) on pure black (`#000`) — it causes eye strain. Use off-whites and deep grays

### Images and media

Some images look wrong on dark backgrounds. Use Tailwind's dark variant to adjust:

```erb
<img class="rounded-lg dark:brightness-90 dark:contrast-105"
     src="<%= image_url %>"
     alt="<%= alt_text %>">
```

### Test both modes

After any UI change, visually verify in both light and dark mode before considering the work done. Toggle the mode and check:
- Text is readable against its background
- Borders and dividers are visible
- Interactive elements have clear hover/focus states
- Images and icons don't disappear

---

## Responsive Design

Every layout must work across screen sizes. Use Tailwind's mobile-first breakpoint system — start with the mobile layout, then add larger breakpoints.

### Mobile-first approach

```erb
<%# Mobile: stack, Tablet: side-by-side, Desktop: with sidebar %>
<div class="flex flex-col md:flex-row lg:grid lg:grid-cols-[250px_1fr]">
  <nav class="p-4 md:w-64 lg:w-auto">...</nav>
  <main class="p-4 flex-1">...</main>
</div>
```

### Common responsive patterns

```erb
<%# Grid: 1 col on mobile, 2 on tablet, 3 on desktop %>
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">

<%# Hide on mobile, show on desktop %>
<div class="hidden lg:block">

<%# Text size scales with viewport %>
<h1 class="text-2xl md:text-3xl lg:text-4xl">

<%# Padding increases at larger breakpoints %>
<section class="px-4 md:px-8 lg:px-16">
```

### Touch targets

Interactive elements need adequate size on mobile. The minimum touch target is 44x44px:

```erb
<button class="min-h-[44px] min-w-[44px] px-4 py-2">
```

---

## Accessibility

Styling affects accessibility directly. Good visual design makes interfaces usable for everyone.

### Focus states

Every interactive element needs a visible focus indicator for keyboard navigation:

```erb
<button class="... focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2">
```

Use `focus-visible` (not `focus`) so the ring only shows for keyboard users, not mouse clicks.

### Color is not the only indicator

Don't rely on color alone to communicate state. Pair colors with icons, text, or patterns:

```erb
<%# WRONG — only color indicates error %>
<input class="border-error-500">

<%# RIGHT — color + icon + text %>
<input class="border-error-500" aria-invalid="true" aria-describedby="email-error">
<p id="email-error" class="flex items-center gap-1 text-sm text-error-600 dark:text-error-400">
  <%= inline_icon(:alert_circle, "w-4 h-4") %>
  Please enter a valid email address
</p>
```

### Semantic HTML first

Use the right HTML element before reaching for ARIA. A `<button>` is better than a `<div role="button">`. A `<nav>` is better than a `<div aria-label="navigation">`.

### Screen reader utilities

Use Tailwind's `sr-only` class for content that should be announced but not displayed:

```erb
<button class="p-2">
  <%= inline_icon(:trash, "w-5 h-5") %>
  <span class="sr-only">Delete bookmark</span>
</button>
```

### Motion preferences

Respect `prefers-reduced-motion` for users who are sensitive to animation:

```erb
<div class="transition-transform duration-300 motion-reduce:transition-none motion-reduce:transform-none">
```

---

## Anti-Patterns

| Don't | Do Instead | Why |
|-------|-----------|-----|
| `style="color: red"` | `text-error-500` | Inline styles bypass the design system |
| `bg-[#3b82f6]` | `bg-primary-500` | Arbitrary values can't be updated centrally |
| Copy-paste 15 classes | Extract a component | Components are the reuse mechanism |
| Write raw CSS in `.css` files | Use Tailwind utilities or `@apply` in `@layer` | Plain CSS diverges from the system |
| `p-[13px]` | `p-3` (or extend the config) | Arbitrary spacing breaks visual rhythm |
| Forget `dark:` variants | Always pair light and dark | Half the users see a broken UI |
| Forget responsive breakpoints | Start mobile-first, add `md:` / `lg:` | Mobile users are the majority |
| Use `focus:` for focus rings | Use `focus-visible:` | Avoids focus rings on mouse clicks |
| Remove outline without replacement | `focus:outline-none focus-visible:ring-2` | Keyboard users need to see focus |

---

## Checklist for UI Changes

1. **Check existing components** — is there a partial, ViewComponent, or shared pattern that already handles this?
2. **Use design tokens** — colors, spacing, and sizes from `tailwind.config.js`, not arbitrary values
3. **Keep classes lean** — use shorthand, drop defaults, maintain consistent order
4. **Dark mode** — every color-related class has a `dark:` pair
5. **Responsive** — layout works from mobile up, touch targets are 44px minimum
6. **Accessibility** — focus-visible states, semantic HTML, sr-only labels for icon-only buttons
7. **No plain CSS** — all styling through Tailwind utilities or `@apply` in `@layer components`
8. **No inline styles** — never use the `style` attribute
