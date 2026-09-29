# PRD 21: Online Lookup Enhancements (P2)

## Status: preserved-tags shipped; clustering not started

Already delivered before this review: the search/match/apply flow across
Discogs and MusicBrainz, a before/after comparison of every field that will
change, per-field opt-in chips, per-file opt-out, and confidence badges.

Delivered here:

- **A preserved-tags list.** `LookupSettings.preservedFields` names the tag
  fields an online apply must never overwrite. The list is applied *after*
  the per-field selection, so it wins: a user who ticked both "apply rating"
  and "preserve my ratings" keeps their rating.
- **ReplayGain is preserved by default.** It is the one case where an apply
  is unambiguously destructive — a lookup result cannot regenerate loudness
  data, so overwriting it loses work a scanner produced and leaves the file
  silently wrong.
- **Four presets** (ReplayGain, Ratings & Mood, Personal notes, Identifiers)
  plus individual field chips. Presets tick only when the whole group is
  preserved, so the checkbox never lies about a partial group.
- The applicator takes the preserved set by injection, and the provider
  *watches* the setting, so editing it takes effect without a restart.

Not delivered, and why:

- **Album clustering (Ctrl+Shift+C).** This is the larger half of the PRD: a
  group-by view over the custom-painted grid, collapsible group rows,
  fuzzy-tolerance clustering, and drag-out. It is a substantial feature with
  real risk to the grid's scroll and selection model, and it is recorded
  here rather than half-landed after the preserved-tags work.
- **Per-apply "include preserved tags" override.** The applicator accepts the
  set per instance, so the seam exists; the checkbox in the apply panel does
  not.
- **Colour-coded add/change/remove diff and a "show changes only" filter.**
  The comparison already shows old struck through and new in bold, which
  conveys direction without relying on colour.
- **Per-file field-level exclusion.** The field chips are global to the
  apply; per-file opt-out already exists.

## Problem Statement

PRD 04 covers the core online metadata lookup workflow (search, match, apply). However, several features that make this workflow robust for real-world use are missing: there's no way to automatically group files by album before lookup, no visual comparison of what will change, and no mechanism to protect specific tags from being overwritten. These gaps mean users must manually organize files, can't easily review changes, and risk losing personal metadata (genres, ratings, ReplayGain) when applying online data.

## Goals

- Add album clustering to streamline batch lookup for mixed-album folders.
- Provide a clear tag comparison view showing original vs. new values before applying.
- Let users define a preserved tags list to protect specific fields from overwrite.

## Functional Requirements

### Album Clustering (Auto-Group for Lookup)

- "Cluster" action (toolbar button, Ctrl+Shift+C) groups loaded files into album clusters based on existing metadata.
- Clustering algorithm:
  1. **Album** (primary key) — files with the same album name are grouped together.
  2. **Album Artist** (secondary key) — disambiguates albums with the same name by different artists.
  3. **Disc Number** (tertiary) — keeps multi-disc releases together as one cluster.
- Files missing both album and album artist tags go into an "Unclustered" group.
- Clusters appear as collapsible groups in the file list, with a header row showing:
  - Album name
  - Album artist (if available)
  - File count
  - Total duration
- Expanding a cluster shows its member files in track-number order (or filename order if no track numbers).
- Users can toggle between clustered view and flat list view.
- Clustering is non-destructive — it's a view/grouping operation, not a file modification.

#### Cluster Operations
- **Lookup cluster**: Right-click a cluster header → "Look Up" pre-fills the search dialog with the cluster's album/artist and selects all files in the cluster.
- **Select cluster**: Clicking a cluster header selects all files in that cluster.
- **Remove from cluster**: Drag a file out of a cluster to move it to Unclustered (for correcting mis-groupings).
- **Merge clusters**: Drag one cluster header onto another to combine them (for split albums that should be together).

#### Fuzzy Matching
- Album name matching is case-insensitive and normalizes whitespace.
- Disc indicators in album names (e.g., "Album Name (Disc 1)", "Album Name [CD 2]") are recognized and grouped together.
- Optional fuzzy tolerance for minor spelling variations — configurable sensitivity in settings.

#### Auto-Cluster Setting
- Setting (default: off): automatically cluster files when a folder is loaded.
- When enabled, the clustered view is shown immediately after loading completes.

---

### Tag Comparison View (Original vs. New)

- When online metadata is fetched and matched to files, display a comparison panel showing:
  - **Original Value** (current tag in the file) vs. **New Value** (from the online source) for each field.
  - Color coding:
    - Green = new tag being added (field was empty, now has a value)
    - Orange/yellow = existing tag being changed
    - Red = tag being removed (had a value, new source has none)
    - Default/grey = unchanged
- The comparison view is shown in the apply preview step and remains visible until the user confirms or cancels.
- Users can click individual fields to toggle them on/off (exclude specific changes per file).
- "Show changes only" filter to hide unchanged fields and focus on differences.
- When multiple files are selected, the comparison view shows per-file rows with expandable detail.
- Preserved tags (see below) are marked with a lock icon and "preserved" label — the user can see what *would* change but the apply action won't touch them.

#### Reuse Beyond Lookup
- The tag comparison view component is reusable by the general tag editing workflow — any pending tag modification can show original vs. new in the tag edit panel.
- PRD 03 (Tags from Filename) apply preview should also use this component.

---

### Preserved Tags List

- A user-configurable list of tag field names that should **never** be overwritten when applying online metadata.
- Configured in Settings → Online Lookup section.
- UI: a tag-chip input where users type field names and press Enter to add them. Each chip has an × to remove.
- Default preserved tags: empty list (all fields eligible for update).
- Common use cases: protecting ReplayGain values, personal genre assignments, ratings, custom tags, play counts.
- When applying metadata, preserved tags are skipped regardless of the "overwrite existing" checkbox state.
- Preserved tags can be temporarily overridden per-apply via an "Include preserved tags this time" checkbox in the apply dialog.
- The preserve list applies to both MusicBrainz and Discogs apply operations.
- Suggested presets (one-click add):
  - "ReplayGain" — adds `replaygain_track_gain`, `replaygain_track_peak`, `replaygain_album_gain`, `replaygain_album_peak`
  - "Ratings" — adds `rating`, `popularimeter`
  - "Play counts" — adds `play_count`, `playcount`

---

## Settings Additions

- **Preserved tags list** — tag-chip input in Settings → Online Lookup.
- **Auto-cluster on load** — boolean toggle (default: off).
- **Cluster fuzzy tolerance** — slider or dropdown (Exact / Loose) for album name matching sensitivity.

## Non-Functional Requirements

- Clustering 1,000 files should complete in <500ms.
- Tag comparison view should render within 200ms for 50 files × 15 fields.
- Cluster view should not degrade scroll performance compared to flat list.
- Cluster state is session-only (not persisted across app restarts).

## Dependencies

- **PRD 01 (Folder Loading & File Display)** — Clustering extends the file list with grouped display.
- **PRD 04 (Online Metadata Lookup)** — This PRD enhances the existing lookup workflow; the apply action and settings page are extended.
- **PRD 00 (TagLib FFI Integration)** — Preserved tags require the writer to selectively skip fields.

## Out of Scope

- Clustering by audio fingerprint similarity (too slow for a UI action; use PRD 04's AcoustID for identification).
- Automatic album identification from clusters (clustering groups files, it doesn't identify which MusicBrainz release they belong to — that's still the lookup step).
- Persistent cluster assignments saved to files.
- Tag comparison for non-lookup edits (the component is reusable, but wiring it into inline editing is a separate effort).
