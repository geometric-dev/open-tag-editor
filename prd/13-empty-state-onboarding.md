# PRD 13: Empty State & Onboarding (P3)

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
