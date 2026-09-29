# PRD 15: Accessibility & Theming (P4)

## Status: mostly shipped

Already delivered before this review: theme mode (system/light/dark), focus
rings on inputs and cells, tooltips on icon-only buttons, and per-field
focus nodes in the tag panel that commit on blur.

Delivered here:

- **High-contrast themes.** The default palette is generated from a seed
  colour, which produces mid-tone borders and text-on-surface pairs that a
  low-quality display cannot resolve. The high-contrast variants push
  surfaces to the extremes, make outlines unambiguous, and double divider
  thickness. Opt-in, and the brand hue is preserved.
- **Interface text size** (75%–150%), applied through `MediaQuery.textScaler`
  and clamped, so it *composes* with the operating system's own text scale
  instead of overwriting it. Discrete options rather than a slider, so the
  value is reproducible between sessions.
- **Semantics on grid rows.** One node per row carrying the filename, a
  capped spoken summary (title, artist, album, unsaved state) and selection
  state — deliberately not one node per cell, which would make a large
  library unusable.
- **A live region on the status bar**, so the result of a save or a load is
  announced rather than being silent.
- **A labelled node on the error count**, which is a `GestureDetector` and so
  previously announced as nothing at all.

Note on what was *not* changed: the toolbar buttons already have accessible
names, because `IconButton` promotes `tooltip` to the button's label and
drops the icon from the semantics tree. Adding an explicit `Semantics` there
would have produced a duplicate name, so it was deliberately left alone.

Not delivered, and why:

- **Toolbar label option** (icon-only vs icon-and-text). The toolbar is
  densely packed by design and the tooltip already names every control.
- **`FocusTraversalGroup` / explicit focus order.** The grid manages its own
  focus; a traversal group would compete with the arrow-key selection model
  rather than help it.
- **Reduced-motion handling.** No animation in the app is load-bearing enough
  to need suppressing, so the plumbing would be inert.

## Problem Statement

The app uses hardcoded small font sizes (11-13px), relies on icon-only toolbar buttons, and lacks explicit accessibility semantics on custom widgets. Users with visual impairments or those who prefer larger text have no way to adjust the UI density.

## Goals

- Improve accessibility for users with visual or motor impairments.
- Provide UI scaling and theming options.
- Add proper semantics for screen reader compatibility.

## Functional Requirements

### Font Scaling
- Settings option for UI scale factor (75%, 100%, 125%, 150%).
- All text sizes, icon sizes, and spacing scale proportionally.
- Data grid row height adjusts to accommodate larger text.

### High Contrast Theme
- Add a high-contrast light and high-contrast dark theme option.
- Ensure all interactive elements meet WCAG AA contrast ratios in all themes.

### Toolbar Labels
- Settings option to show text labels below or beside toolbar icons.
- Default: icons only (current behavior). Option: icons + labels, or labels only.

### Semantic Labels
- Add `Semantics` widgets to:
  - Data grid rows (announce file name and selection state)
  - Tag indicator icons (announce "tagged" or "untagged" and format)
  - Status bar segments (announce counts and durations)
  - Toolbar buttons (already have tooltips, ensure they map to semantic labels)

### Focus Visibility
- Ensure all interactive elements show a visible focus ring when navigated via keyboard.
- Custom widgets (data grid cells, address bar) must participate in the focus traversal order.

### Reduced Motion
- Respect the OS "reduce motion" setting. Disable animations (e.g., drag overlay transitions) when active.

## Non-Functional Requirements

- Accessibility improvements must not degrade performance.
- Full WCAG AA compliance requires manual testing with assistive technologies and expert review.

## Dependencies

- None.

## Out of Scope

- Full WCAG AAA compliance.
- Localization/internationalization (separate effort).
- Custom color theme editor.
