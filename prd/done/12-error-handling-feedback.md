# PRD 12: Error Handling & User Feedback (P3)

## Status: shipped

Delivered: the error details panel with per-row and bulk retry, the 500-entry
bounded log, corrupt-file handling via `readError`, snackbar notifications
with a "View Details" action, and a status-bar error count.

Added after the initial review:

- A toolbar **Error Log** button carrying the live count, so the panel stays
  reachable. The status bar toggles it on click, but it only renders when
  there are errors — a user who had dismissed the panel had no way to find
  it again without producing a new failure.
- Removed `NotificationService`, which was never instantiated. Its logic was
  inlined at its call sites, so it was dead weight that looked like the
  project's snackbar abstraction while being nothing of the sort.

Not delivered, and why:

- **Per-row retry as a right-click action.** It is a button on each row
  instead, which works on every platform. A grid context menu is wanted by
  PRD 18 too and is better built once.

## Problem Statement

Errors during batch operations (tag reading, writing, renaming) are either silently swallowed or shown as a brief snackbar with no detail. Users have no way to see which specific files failed, why they failed, or retry the failed subset.

## Goals

- Surface errors clearly with actionable detail.
- Provide a persistent error log for the session.
- Enable retry of failed operations.

## Functional Requirements

### Error Notification
- When a batch operation has failures, show a snackbar with a "View Details" action button.
- The snackbar persists until dismissed (not auto-hide) for error-level messages.
- Success-only messages can auto-hide after 3 seconds.

### Error Details Panel
- A collapsible panel (or dialog) showing a list of failed files with:
  - File path
  - Operation attempted (read, write, rename)
  - Error message
  - Timestamp
- Accessible from the status bar (click on error count) or via a menu item.

### Retry Failed
- "Retry All Failed" button in the error details panel re-attempts the failed operations.
- Individual file retry via right-click or action button per row.

### Corrupt File Handling
- Files that fail to read during folder loading are included in the file list with a visual error indicator (e.g., red icon in tag indicator column).
- Tooltip on the error indicator shows the read error message.
- These files can still be selected for rename operations (filename is known even if tags aren't).

### Status Bar Integration
- When errors exist in the session, the status bar shows an error count with a warning icon.
- Clicking the error count opens the error details panel.

## Non-Functional Requirements

- Error log retains up to 500 entries per session.
- Error panel renders smoothly even with many entries (virtualized list).

## Dependencies

- None beyond existing infrastructure.

## Out of Scope

- Persistent error log across sessions (file-based logging).
- Automatic error reporting to a remote service.
