# PRD 15: Accessibility & Theming (P4)

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
