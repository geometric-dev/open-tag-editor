# Changelog

All notable changes to Open Tag Editor are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/) while pre-1.0.

## [Unreleased]

## [0.6.0] - 2026-11-19

A new **rule-based rename profiles** feature: get "Standard" / "Various
Artists" / "Compilation" / "multi-disc" naming picked automatically from
tags, instead of manually flipping presets.

### Added
- **Rename profiles** (Settings ▸ File Renaming). A profile is a name, a
  mask pattern, and one or more **condition groups**. Each group is a set of
  conditions that are ANDed together; the groups are ORed. The rename dialog
  picks the first profile (top-to-bottom) whose conditions match the current
  selection and applies its pattern automatically.
- **Multiple alternatives per profile, one pattern.** This is the answer to
  "same rule for AlbumArtist = OST *or* VA *or* Soundtrack": put each value
  in its own condition group within a single profile. You maintain the
  pattern in exactly one place rather than duplicating a near-identical
  profile per value.
- **Flexible match conditions.** Any tag field (case-insensitive) plus a few
  computed pseudo-fields: `discCount` / `trackCount` (the "/total" part of a
  track/disc number) and `folderDepth`. Operators: equals, not equals,
  contains, does not contain, is set, is not set, and is greater than
  (numeric).
- **Built-in starter profiles** (editable/deletable, not locked): a
  multi-alternative *Various Artists / OST / Soundtrack* profile, a
  *Multi-disc* profile (`discCount > 1`), and a *Standard* catch-all. Order
  is meaningful — specific profiles above general ones; the catch-all stays
  last.
- Profiles are persisted and managed from the settings pane: add, edit,
  delete, and reorder (move up/down = higher/lower priority). Legacy
  single-group profiles saved by earlier builds still load (migrated to a
  one-group shape).

## [0.5.3] - 2026-11-19

Small quality-of-life fix: the rename-related dialogs now reopen on the
preset you last used.

### Changed
- **The rename dialogs remember the most recently used preset.** Both
  **Rename Files** and **Tags from Filename** previously reopened on the
  first preset in the list, regardless of what you last picked. They now
  restore the last-applied preset on open, and selecting a preset records
  it. The choice is persisted by preset *name*, not index, so it stays
  correct when user presets are added or deleted (which shifts indices).

## [0.5.2] - 2026-11-19

Bug-fix release for the in-app updater's Windows install step.

### Fixed
- **The Windows updater no longer opens a terminal window that spins
  forever on "find".** Clicking *Restart & Install* launched a batch file
  that polled for the app's PID with `tasklist | find` in a detached
  console. Without a real attached console the `find` never returned, so a
  visible terminal window opened and sat there indefinitely; closing the
  main window did nothing and closing the terminal killed the swap, leaving
  the app to restart into the old build. The install step is now a
  PowerShell script that waits on the process by PID with `Wait-Process`
  and is launched with `-WindowStyle Hidden`, so no window appears and the
  wait actually completes. The macOS/Linux path got the same quoting
  hardening for paths containing quotes or `$`.

## [0.5.1] - 2026-11-19

Bug-fix release for three regressions found in 0.5.0. No new features.

### Fixed
- **Renaming a file out of the loaded folder no longer produces a
  `../../../..` breadcrumb.** After a successful rename the list is
  refreshed in place, but the folder dividers are grouped relative to the
  loaded root. A file that moved outside that root made `p.relative` emit
  `..` segments, so the divider read `.. / Other` (or deeper). The refresh
  now partitions renames by scope: files that stayed inside the root keep
  their place with updated paths, and files that left the root are dropped
  from the list and selection — they no longer belong to the loaded folder.
  `computeRelativePath` also falls back to the folder's own name rather than
  ever rendering a `..` breadcrumb, as a defensive backstop.
- **The rename preview no longer blanks out after a preset is applied.**
  The renamer state provider watched the file list and selection, so any
  change to either — most visibly the `applyRenames` + `remapPaths` pair
  that runs after a rename — disposed the autoDispose notifier and recreated
  it with an empty state, wiping the previews mid-dialog. The dialog is the
  provider's only consumer and is modal, so the file set is now captured once
  when it opens and the provider no longer watches the list.
- **A mask variable followed by a value no longer swallows the preceding
  separator.** With `%artist\%album\%disc%track` and an empty disc, the
  backslash between `%album` and `%disc` was dropped, producing
  `Artist\Album01` instead of `Artist\Album\01`. The delimiter-collapsing
  pass only removed a separator when it genuinely dangled (nothing on either
  side); it now keeps a separator that still has a value on its left and a
  value on its right. Leading, trailing, and last-position empty variables
  still collapse correctly.

## [0.5.0] - 2026-11-18

A release about the two operations users repeat most — loading a folder and
renaming its files — plus the first built-in update path, so a released build
can find the next one.

The theme is *stop waiting and stop losing work*. A large folder used to
freeze the grid with no way out; a rename that half-failed used to vanish
behind a 30-second snackbar. Both now report what they are doing, both can be
stopped or retried, and neither loses the user's place in the list.

### Added
- **In-app updates.** The app asks GitHub's releases API for the newest
  published version and compares it to the version compiled into the build
  (from `pubspec.yaml` via `AppVersion.current`). A new **Update button** in
  the toolbar shows state at a glance — up to date, checking, downloading
  with a percentage, or ready to restart — and opens a dialog with the
  release notes and a download/install action. On first launch the app asks
  once whether to check automatically; the answer and the fact that the
  question was asked are both persisted, so it is asked once, not once per
  release. Settings ▸ General gains a checkbox for background checking and a
  **Check for Updates Now** button. Downloads are streamed to a staging
  directory and swapped in by a helper script on restart, so an interrupted
  download never leaves a half-written app behind. Update checks are
  read-only until the user confirms.
- **A cancellable folder load with live progress.** Loading a folder now
  reports *Scanning… N audio file(s) found* and then *Reading tags: X of Y* as
  it goes, with a determinate bar for the read phase and an indeterminate one
  for the scan. A **Cancel** button sits in the status bar while a load is in
  flight: the scan stops between directory entries, the tag read stops between
  50-file chunks, and whatever was already read stays in the grid rather than
  being thrown away. Starting a second load cancels the first. The status line
  is a live region throughout, so the progress is announced, not merely drawn.
- **Select a whole folder from its separator row.** Clicking a folder header
  now selects every file under it; Ctrl-click toggles the group, Shift-click
  takes the contiguous range from the anchor through the group, and
  Ctrl+Shift-click adds that range to the existing selection. Range selection
  stays group-aware afterwards — extending a selection past a folder-selected
  anchor spans from the group's edge, not its first file. The separator shows
  a selected state so the group is visibly part of the selection.
- **Read-only files are a first-class rename case.** Before renaming, the
  dialog inspects the filesystem (not just an open-for-write probe, so files
  held by a media player or indexer are not misreported) and, if any target
  is read-only, asks: **Rename** (clear the attribute and proceed),
  **Skip** (leave those files and rename the rest), or **Cancel**. The same
  `FileUtils.isFileReadOnly` / `clearReadOnly` pair backs the read-only badge
  in the tag panel and the ID3/TagLib readers, so one definition decides
  what "read-only" means everywhere.
- **Rename failures are reported in the grid, not just in a toast.** A failed
  rename now flags the file row with an error indicator and its message, and
  opens a persistent *Rename Incomplete* dialog listing each failure — a
  30-second snackbar was the wrong shape for a result the user has to act on.
  Successful renames update the in-memory list in place (path, filename and
  extension, tags preserved) and remap the current selection, so the grid
  does not have to be reloaded from disk to reflect what just happened.

### Changed
- **Folder loading is progressive.** Tags are read in 50-file batches with a
  yield between them, so the grid fills in and the UI stays responsive on a
  multi-thousand-file folder instead of blocking on one large isolate call.
  A load can be cancelled at each stage, and the in-memory list is updated
  incrementally rather than in one final swap.
- The read-only check moved out of the two tag readers into
  `FileUtils.isFileReadOnly` (with an optional pre-fetched `FileStat`), so the
  same file is not stat'd and probed twice per read.

### Fixed
- Read-only detection no longer opens every file for append just to ask
  whether it is writable. On Windows the `FILE_ATTRIBUTE_READONLY` bit is
  read from the file's attributes and cleared with `SetFileAttributesW`; on
  POSIX the owner write bit is checked. Files locked by another process are
  no longer misclassified as read-only, and a large folder read no longer
  pays for an open/close per file.
- The folder-load progress bar can no longer overflow its track if the
  completed count exceeds the total; the fraction is clamped.
- A rename that partially failed no longer dismisses its own result before it
  can be read: the summary moved from a timed snackbar to a dialog, and the
  per-file errors persist in the list.

### Docs
- CHANGELOG now documents the auto-update, cancellable-load, folder-group
  selection and read-only-rename work that had accumulated since 0.4.0.
- CI accepts `v*` tag pushes: the format/analyze/test and three-platform
  build pipeline verifies the tagged tree, then a publish job fails hard if
  the tag disagrees with `pubspec.yaml`, repackages the build artifacts into
  the usual bundle archives, extracts these notes from this changelog and
  attaches them to a GitHub release. Branch builds keep building artifacts
  without publishing.

## [0.4.0] - 2026-10-19

First tag and GitHub release: the bundles CI builds on every push
(Windows, macOS universal, Linux x64) are attached to the release page, so
a tag finally exists to identify the build the branch has been verified
with since 0.3.0.

The theme is working features that said nothing about themselves: a grid
that left delete and save undiscoverable, drag-reorder without a visible
handle, shortcuts no help entry listed — and destructive operations whose
notices described the opposite of what they do.

### Added — visible affordances
- **File row context menu** on the grid (PRD 18's outstanding right-click
  requirement; PRD 12's per-row retry). Delete-to-remove and save were
  reachable only by keyboard, with no visible affordance. The menu acts on
  the current selection — a row outside it is selected first, so acting on
  a row the user did not select never happens behind a menu opened on it —
  and pluralises its wording off the selection size. Right-click is
  suppressed while a cell is being edited.
- **Help ▸ Keyboard shortcuts** (toolbar button and F1, the platform
  convention): every binding, grouped the way a user thinks about them —
  files, editing, selecting, saving, windows — rather than by which file
  owns the binding. Until now only Save, Undo and Redo named their
  shortcut; Ctrl+Arrow, Ctrl+Space, F5, Ctrl+Shift+Home/End, Alt+arrows,
  Ctrl+G and Page Up/Down all worked and were entirely undiscoverable.
  The list is hand-maintained in `ShortcutReference`; tests pin no
  duplicate keys, no blank entries, and that the previously hidden
  bindings really are listed.
- **A drag grip on column headers.** Drag-to-reorder worked but advertised
  only Move Left / Move Right in the context menu, although PRD 16 shipped
  drag as the primary interaction. A `drag_indicator` appears on hover, so
  it costs no space at rest; pinned columns (tag indicator, filename) show
  none, matching what the drop target actually accepts; the handle is
  semantically announced as one.
- **A determinate progress bar while a folder loads**, above the grid. The
  grid previously stayed visually identical to idle during a
  multi-thousand-file isolate read, and a click that appears to do nothing
  is a reasonable conclusion. The file count is known once listing
  completes, so the bar is determinate rather than a spinner, and it is a
  live region: the running count is announced as it advances, not only at
  the end. The width factor is clamped so a miscounted total cannot
  overflow the bar.

### Fixed — what actions claim versus what they do
- **No-op commands no longer consume the undo stack.** `execute()`
  returned void, so the manager pushed entries unconditionally: press
  Enter in a tag field without editing it, then Ctrl+Z, and the undo was
  spent on an entry that did nothing — putting the real previous state one
  step further away and wiping the redo stack. Commands now report whether
  anything changed; both the stack push and the redo clear are skipped
  when they did not. Fixed at the manager, so every future entry point
  inherits it.
- **The bulk-edit notice described the opposite of what happens.** It read
  "Empty fields will not be changed" while clearing a populated field
  removes that tag from *every* selected file (the writer hands an emptied
  field to TagLib as a delete — verified by probe). The behaviour stays:
  emptying is the only bulk tag-removal path in the panel. The notice now
  states both halves of the contract — typing overwrites in every file,
  clearing removes from every file — and a test fails if the old wording
  ever comes back.
- **The lookup apply panels say what they do to fields the release page
  has no value for.** They skip those fields — correct, because a release
  with no track number must not wipe the one already on the file — but
  with no wording it read as the apply having failed, and a skipped field
  was indistinguishable from a successful one. The full-match and
  partial-match panels now both say it, and point at Tools ▸ Clear Fields
  as the way to actually remove tags.
- **Tag panel tabs render with no file selected.** The panel returned
  early, so the tab row never appeared and File Info — format, size,
  bitrate, sample rate: exactly the tab wanted while deciding what to
  select — was unreachable. Tags and Album Art now render their own empty
  state instead of a full set of editable fields with no target files.
- **The Tools menu visibly separates its destructive actions.** The four
  data-removing items sit under a labelled header ("Removes data — each
  asks first", which is true: all four open a confirmation), rather than
  a rename sitting directly above Clear All Tags behind an unlabelled
  divider. Menu wording comes from one table shared with the dispatch
  switch, so menu and action cannot disagree; 'Remove ID3v1 Tag' gains the
  confirmation-dialog ellipsis every other destructive item already had;
  and the cover-art item's '...' becomes a real ellipsis.

### Changed
- The toolbar's two group dividers come from one named widget instead of
  two inline `VerticalDivider`s that happened to share their metrics, so
  restyling one keeps both. No behaviour change.

### Docs
- README, CONTRIBUTING and the roadmap claims checked against the code:
  corrected platform table and prerequisites (Flutter 3.41 / Dart 3.10,
  fvm pins 3.47.5), the clone URL placeholder, the FFI bindings described
  as committed (they are, via an explicit .gitignore negation), the full
  set of 21 supported extensions, and a roadmap whose Known Limitations
  section names the actual blockers: whole-block tag removal needs a
  native call that does not exist, ReplayGain cannot be calculated
  anywhere, no signed installer, and the undiagnosed ID3v1 Linux issue.

## [0.3.0] - 2026-09-29

Verified release: Windows, macOS (universal) and Linux bundles are built and
structurally checked on every push, and the whole suite runs on Windows and
Linux with a lint-clean tree enforced in CI.

The headline fix is that **editing a multi-value tag no longer flattens it**.
Reading had always joined values with `"; "`, but the writer passed that
joined string straight through, so the first ordinary edit of a field holding
two artists turned two ARTIST properties into one property literally
containing `A; B`. Multi-value fields are now written as real repeated
properties, verified against the library on both ID3v2 and Vorbis Comment.

Also new: tag deletion and cleanup, ReplayGain read/display/clear, a
preserved-tags list for online applies, drag-reorderable column headers, an
empty state that is a usable starting point, high-contrast themes, text
scaling and screen-reader semantics, a confirm-before-save setting, and
Ctrl+Arrow / Ctrl+Space / F5 navigation.

### Added — accessibility and theming (PRD 15)
- **High-contrast themes.** The default palette is generated from a seed
  colour, producing mid-tone borders and text-on-surface pairs that a
  low-quality display cannot resolve. The high-contrast variants push
  surfaces to the extremes, make outlines unambiguous and double divider
  thickness. Opt-in; the brand hue is preserved.
- **Interface text size** (75%–150%), applied through `MediaQuery.textScaler`
  and clamped, so it composes with the operating system's own text scale
  rather than overwriting it. Discrete options, so the value is reproducible
  between sessions.
- **Semantics on grid rows**: filename, a capped spoken summary (title,
  artist, album, unsaved state) and selection state. One node per row, not
  per cell — a per-cell node on a large library is unusable.
- **A live region on the status bar**, so the result of a save or a load is
  announced instead of being silent.
- **A labelled node on the error count**, which is a `GestureDetector` and
  previously announced as nothing.

### Fixed — online lookup (PRD 21)
- A **partial** match apply now honours the preserved-tags list, like a full
  match already did. A user who protected ReplayGain kept it on one apply
  path and lost it on the other.
- A failed cover-art fetch is no longer swallowed. Every sibling error path
  in the lookup state provider reported to the error log; this one did not,
  so the apply panel offered an "apply cover art" checkbox that silently did
  nothing.

### Added — online lookup (PRD 21)
- **A preserved-tags list** for online metadata applies, with ReplayGain
  preserved by default. An apply is the one place where ReplayGain is
  unambiguously destroyed: a lookup result cannot regenerate loudness data,
  so overwriting it loses real work and leaves the file silently wrong.
- The preserved set is applied *after* the per-field selection, so it wins
  when a user has ticked both "apply rating" and "preserve my ratings".
- Four presets (ReplayGain, Ratings & Mood, Personal notes, Identifiers)
  plus individual field chips. A preset ticks only when its whole group is
  preserved, so the checkbox never misreports a partial group.
- The applicator takes the preserved set by injection and the provider
  watches the setting, so a change takes effect without a restart.

### Fixed — multi-value tags (PRD 20)
- **Editing a multi-value field no longer flattens it on the next save.**
  Reading already joined values with `"; "`, but the writer passed that
  joined string straight to `taglib_property_set`, turning `["A", "B"]` into
  one property containing `"A; B"`. Multi-value fields are now cleared and
  each value appended with `taglib_property_set_append`.
- **Validation no longer rejects its own normalisations.** Multi-value fields
  are compared as value sets rather than raw strings, so dropping an empty
  segment or changing separator does not abort the write.

### Added — multi-value tags (PRD 20)
- A closed set of multi-value fields (artist, album artist, genre, composer,
  conductor, lyricist). Deliberately closed: a value that genuinely contains
  a semicolon, such as `AC/DC; Live`, must not be shredded.
- Separator detection on read for the null-byte, `"; "`, `";"`, `" / "` and
  `"/"` conventions, so a file written by another tool stays readable.
- A chip editor in the tag panel for multi-value fields: one removable chip
  per value plus an inline add field, each edit a single undoable command.
- Verified against the real TagLib DLL on ID3v2 and Vorbis Comment files,
  including replace-does-not-append and clear-removes-every-value.

### Added — drag-and-drop (PRD 16)
- Drag-to-reorder column headers. Long-press to pick a header up; an
  insertion line marks the gap it will land in, and the drop converts that
  gap into a post-removal index before reaching the notifier. The fixed
  columns are not draggable at all, so a drag can never be silently rejected
  on drop, and nothing can be dropped before the first column.
- `ColumnConfigNotifier.moveColumn` implements the post-removal index
  convention the drag uses, leaving `reorderColumn` for the menu's
  Move Left / Move Right, which pass raw indices.

### Added — empty state and onboarding (PRD 13)
- A real empty state: app icon, drop hint, the supported-format list
  generated from `SupportedFormats` (so it cannot drift from what actually
  opens), Open Folder / Open Files buttons, a Settings link, up to 6 recent
  folders, and four feature highlights.
- `EditorOpenService` now owns the open-folder and open-files logic, shared
  by the toolbar and the empty state. Recent-folder entries load through the
  same `FolderLoadingService` and the same unsaved-changes guard, so no entry
  point can quietly skip them.

### Added — keyboard navigation (PRD 10)
- **Ctrl+Arrow** moves the cell focus without changing the selection. Plain
  arrows collapse the selection onto the focused row, so there was no way to
  reach a row to act on it *outside* the current selection. The anchor stays
  put so a later Shift+click still extends from where the user expects.
- **Ctrl+Space** toggles the focused row in or out of the selection.
- **F5** re-reads tags from disk, preserving the selection, undo history and
  loaded folder. Files with unsaved edits are skipped rather than
  overwritten, and the status bar says how many were skipped.

### Added — error handling (PRD 12)
- Toolbar **Error Log** button showing the live error count, so the error
  panel is always reachable. The status bar already toggled the panel, but
  it only renders when errors exist, so a user who had dismissed the panel
  could not reopen it without producing a new failure.

### Removed
- `NotificationService`, which was never instantiated. Its snackbar logic
  had been inlined at the call sites, so it only looked like the project's
  notification abstraction.
- Dead code found by a quality audit and verified unreferenced across
  `lib/` and `test/`: `BatchNotification`, four superseded selection/file
  providers, `ConflictDetector.autoIncrement` (a second, unused
  implementation of "append (1) until unique" that also disagreed with the
  live one on case sensitivity), `TrackMatcher._matchByDuration` (~60 lines
  hidden behind an `// ignore: unused_element`), `LookupHelpers`'s
  superseded `mergeResults` and unused `groupTracksByDisc`,
  `MusicBrainzService.getRecordingMetadata`, three settings mutators nothing
  called, and three unreferenced constants — one of which
  (`PartialMatchApplicator.albumFields`) had drifted from behaviour by
  listing a `genre` field the applicator never writes.
- `RenameService` (136 lines) plus its test. Only `RenameResult` and
  `RenameConflictException` from that file were live, so they moved to
  `lib/shared/models/rename_result.dart`; the service itself was reachable
  in production only through a provider nothing read, and the renamer
  feature uses `RenameExecutor` instead.

### Changed — error handling (PRD 12)

### Added — unsaved-changes work (PRD 07)
- **Confirm before saving tags** setting (General ▸ General). All four save
  entry points — toolbar, Ctrl+S, tag panel, and the unsaved-changes guard —
  route through one `SaveConfirmation` helper, so enabling it cannot be
  bypassed by taking a different route to the same write. Off by default;
  dismissing the dialog counts as a cancel, not a silent save.
- Settings notifier tests covering persistence of every general setting,
  including the clamping of the large-folder threshold.

### Added — Tag&Rename parity wave
- **GNUdb lookup** (freedb successor): matches selected album tracks by a
  virtual CD table-of-contents computed from durations; new source chip in
  the lookup dialog.
- **Export wizard formats**: true `.xlsx` via a dependency-free ZIP+OOXML
  writer (inline strings, numeric cells, CRC-checked archive), alongside
  CSV (RFC-4180 + BOM) and HTML.
- **Tags Synchronization wizard**: dialog with direction choice, MP3
  count, fill-preview, and results summary over the new ID3v1 codec
  (v1.1 track byte, Latin-1-safe encoding, in-place replace).
- **Cover art resize/convert**: batch downscale to a max dimension and
  convert JPEG/PNG through the pure-Dart `image` package; single undoable
  command restores every original.
- **Tools menu** hosting transforms, cover-art resize, and sync wizard;
  artist case tools are undoable per-file delta commands.
- `.cdg` karaoke companions now follow their audio file on rename.
- Multi-value tag properties join with `; ` on read instead of silently
  dropping all but the first value.
- **Tag deletion & cleanup (PRD 18)**: Tools menu gains *Clear All Tags…*,
  *Clear Fields…* and *Remove ID3v1 Tag*.
  - *Clear All Tags…* confirms with real counts, and clears only the
    fields the editor manages — frames TagLib does not surface (custom
    ID3v2 frames, for instance) are deliberately left alone rather than
    silently claimed as removed.
  - *Clear Fields…* lists only fields that actually carry a value, marks
    partial fields with an `in N of M files` count, and shows a live
    affected-file preview that recomputes from the same planner the
    command will use, so the number cannot drift from what the button does.
  - *Remove ID3v1 Tag* deletes the 128-byte trailer and reports
    modified/skipped/errors per file.
  - All three are undoable. Clearing rides the normal save path, so
    backups, atomic writes and validation behave exactly as for an edit
    and nothing touches disk until you save; ID3v1 removal writes
    immediately because TagLib's Properties API cannot address that block.

### Added — release engineering
- `scripts/build-taglib.sh` builds the TagLib C bindings from upstream
  source (universal on macOS) into the location each platform's packaging
  expects, so no prebuilt blob has to be trusted or committed.
- `scripts/bundle-crt.ps1` stages the Microsoft Visual C++ runtime into a
  Windows bundle from a licensed toolchain payload, and refuses to
  redistribute the System32 copy.
- `scripts/verify-release.sh` is the POSIX counterpart to the existing
  Windows verifier: it checks the native library's location, architecture
  agreement with the app binary, and that its dependencies actually resolve.
- macOS ships a universal `libtaglib_c.dylib` via a new "Embed TagLib"
  Xcode build phase that runs *before* Flutter's signing phase, so the
  library is covered by the bundle signature.
- Linux packaging installs `libtaglib_c.so` next to the executable (the
  loader's first probe) and the bundle rpath is `$ORIGIN/lib`.
- CI: `format` and `analyze` gates, tests on Windows and Linux, and
  verified release bundles for Windows, macOS and Linux uploaded as
  artifacts. macOS/Linux TagLib is rebuilt from source on every run.
  The SDK is pinned in `.fvmrc`, which every job reads.
- `docs/known-issues.md` records defects that CI has confirmed but that
  are not yet fixed, so a test skip can never quietly hide a regression.
- **ReplayGain (PRD 19)**: the four ReplayGain values are now read, shown
  and clearable.
  - Read-only "ReplayGain" section in the tag panel, collapsed by default,
    showing `varies` for a mixed selection and `Not set` when absent.
    Read-only because these are scanner-calculated values; a text box would
    invite a gain that no longer matches the audio.
  - Optional `RG Track Gain` / `RG Album Gain` columns, hidden by default.
  - Tools ▸ *Clear ReplayGain…* removes only those four fields and is
    undoable, for when an external scanner needs to recalculate.
  - "Clear All Tags" now names the ReplayGain values in its confirmation
    and points at "Clear Fields…" for keeping them.
  - The values previously survived saves only *incidentally* (the writer
    never touched unmapped keys). They are now mapped in both directions
    and therefore explicit, and are still preserved across unrelated
    edits because writes stay delta-based.

### Changed
- SDK floor raised to Flutter 3.41 / Dart 3.10 (the version that replaced
  the APIs this project now uses) and the tree reformatted for the
  modern tall-style formatter; the tree is now analyzer-clean including
  lints, which CI enforces.
- Grid, breadcrumb and quick-switcher tests build their sample paths with
  `package:path` instead of hard-coded `C:\Users\...` literals, so the
  suite exercises the same logic on POSIX hosts. The implementation was
  already correct; the assertions were Windows-only.

### Fixed
- Undoing a "Clear Tags" no longer discards tag edits made after the clear:
  the command restores the fields it removed rather than the whole tag map.
  (The existing batch-edit and transform commands still restore whole maps.)
- ID3v1 `_hasTag` read its signature from the wrong offset, breaking
  replace-in-place; append mode no longer resurrects deleted files.
- Toolbar folder/file pickers used `BuildContext` after an `await` without
  re-checking `mounted`.
- `build-taglib.sh` now clones TagLib's `3rdparty/utfcpp` submodule, which
  a shallow clone silently omitted.
- `bundle-crt.ps1` locates the VC++ redistributable payload via `vswhere`
  and a direct glob, covering both the `VC/Tools/MSVC/*/Redist` and
  VS 18's `VC/Redist` layouts, and requires the x64 payload.
- `verify-release.sh` no longer uses a `case` statement inside a
  command substitution, which the bash 3.2 that macOS ships cannot parse,
  and no longer treats `/usr/lib` and `/System` dependencies as missing.
  `otool -L` reports SDK libraries by absolute path, but on a build machine
  those are linker stubs rather than real files, so the check reported a
  false failure on every macOS bundle.



## [0.2.0] - 2026-08-23

Quality and trust release: single save path, background-isolate I/O,
verified Windows packaging, ReplayGain-preservation proof, completed
keyboard navigation, and an enforced CI gate.

### Fixed
- Installed Windows releases silently disabled tag writing: the installer
  placed `taglib_c.dll` under `data\` while the loader only probed the
  executable directory. Loader now probes ordered candidates per platform;
  installers place libraries correctly (verified against a real build).
- Ctrl+S swallowed write failures entirely; all four save entry points now
  share one `TagSaveService` and record failures in the error log.
- Quick switcher rows triggered the framework's invisible-ink assertion
  (19 failing tests).
- Toolbar "Open Folder" bypassed the recursive toggle, threshold guard and
  recent-folder persistence; all load entry points share one service.
- Toolbar no longer hard-codes Segoe UI; each platform uses its system font.
- Provider equality: `AudioFile` now includes tags/art in `==`, preventing
  missed rebuilds on tag-only changes.

### Added
- Keyboard navigation: PageUp/PageDown (move + Shift-extend, edge-clamped),
  Home/End (+Shift), Enter-to-edit, and scroll-follow for the active row.
- Column reorder via header context menu (Move Left/Right), persisted.
- Theme mode setting (System/Light/Dark); backup toggle now persists.
- Session error log records online-lookup failures (informational,
  non-retryable by design) instead of losing them when the dialog closes.
- GitHub Actions CI: analyze on Windows/Linux/macOS runners, tests on
  Windows; committed ffigen bindings so fresh clones compile.
- Tests: TagSaveService, AtomicWriteManager, ValidationEngine, rename
  executor integration, extractor write commands, selection paging, and
  REAL-TagLib round-trip/preservation suites (auto-skip without DLL).

### Changed
- Folder loading runs on a background isolate (`Isolate.run`); bulk saves
  execute atomic writes + validation off the UI thread via settings
  snapshots. Single-file operations stay interactive.
- Removed dead code (pure-Dart writer moved to test fixtures) and unused
  dependencies (freezed/json/riverpod-generator/mockito/logging/etc.).

### Docs
- Honest platform support table + `docs/platforms.md` build guide.
- `docs/2026-08-23-project-review.md`: full architecture/quality review.
- `scripts/verify-release.ps1` bundle checks incl. VC++ runtime warning.

## [0.1.0] - initial public baseline
