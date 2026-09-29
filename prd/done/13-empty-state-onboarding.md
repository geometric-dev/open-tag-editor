# PRD 13: Empty State & Onboarding (P3)

## Status: mostly shipped

Delivered (`EmptyStateView`):

- App icon, "Drop audio files or folders anywhere in this window", and the
  supported-format summary generated from `SupportedFormats` so it cannot
  drift from what the app actually opens.
- **Open Folder** and **Open Files** buttons, plus a **Settings** link.
- Recent folders (capped at 6) that load through the same
  `FolderLoadingService` as every other entry point, behind the same
  unsaved-changes guard.
- Four feature highlights so the first screen says what the app is for.
- Renders synchronously with no async work.

To keep the empty state and the toolbar from drifting, the open-folder and
open-files logic moved into `EditorOpenService` and both call it. A second
hand-written copy of that logic is exactly how an entry point ends up
skipping the unsaved-changes guard or the recursive toggle.

Not delivered, and why:

- **First-run setup prompt** (fpcalc hint, "configure online lookup" card).
  It would need a dismissible-once preference and a home for the banner, and
  an fpcalc call-to-action shown before the user has any files is a poor use
  of the most valuable screen real estate. Better placed in the Online
  Lookup settings pane the card would have linked to, where the setting
  actually lives.
- **Contextual feature hints** ("right-click column headers to show/hide",
  multi-select). A hint is shown once per feature, which means a
  preferences-backed hint registry and a dismissal path. The hints that
  mattered most are now in tooltips and the empty state.

## Problem Statement

New users launching the app for the first time see a minimal empty state with no guidance on supported formats, available features, or required configuration (fpcalc path, API tokens). The app doesn't help users discover its capabilities.

## Goals

- Provide a welcoming and informative empty state.
- Guide first-time users through initial setup.
- Make feature discovery natural without being intrusive.

## Functional Requirements

### Enhanced Empty State
- When no files are loaded, the main area shows:
  - App logo/icon
  - "Drop audio files or folders here" with supported format list (MP3, FLAC, OGG, M4A, etc.)
  - "Open Folder" and "Open Files" buttons (duplicating toolbar for discoverability)
  - Recent folders list (if any exist) for quick re-access
  - Brief feature highlights: "Edit tags, rename files, look up metadata online"

### First-Run Setup Prompt
- On first launch (no `shared_preferences` data exists), show a non-blocking banner or card suggesting:
  - "Configure online lookup" link to Settings → Online Lookup section
  - "Set up fpcalc for audio fingerprinting" with a link to download instructions
- The banner is dismissible and doesn't show again once dismissed.

### Feature Hints
- Contextual tooltips or subtle hints for non-obvious features:
  - Right-click column headers for show/hide
  - Ctrl+Click / Shift+Click for multi-select
  - Recursive toggle explanation
- These appear once per feature, tracked via preferences.

### Settings Quick Access
- The empty state includes a "Settings" link for immediate access to configuration.

## Non-Functional Requirements

- Empty state renders instantly (no async loading).
- Hints must not interfere with normal workflow after first viewing.

## Dependencies

- None.

## Out of Scope

- Interactive tutorial or walkthrough wizard.
- Video guides or external documentation links.
