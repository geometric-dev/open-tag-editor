# Roadmap

0.3.0 is released and verified on all three desktop platforms; see the
CHANGELOG. This file tracks what is left.

## Carried over from 0.2.x

- [ ] Surface "native TagLib missing — writes disabled" as a status-bar state
      instead of silent degradation (architect follow-up from platform review)
- [ ] Golden tests for the data grid; large-library (10k rows) perf pass
- [ ] Wire lookup *apply* results into the error log per-file (today only
      whole-step failures are logged)
- [x] Run `scripts/verify-release.ps1` in CI on a built artifact
- [x] Bundle the VC++ runtime in the Windows bundle (`scripts/bundle-crt.ps1`;
      a signed installer is still outstanding)

## 0.4 — carry-over from 0.3

- [ ] **Whole-block tag removal.** Clear All Tags / Clear Fields / Remove
      ID3v1 shipped, but removing an entire ID3v2, APEv2 or Vorbis block is
      impossible: the bundled `native/taglib_c.h` exposes no removal call,
      only field-level `taglib_property_set`. Needs a native change and a
      rebuilt `tag.dll`.
- [ ] **Multi-value fields as lists, end to end.** Writing, reading, display
      and a chip editor shipped, and the silent flattening bug is fixed. Still
      outstanding: `AudioFile.tags` holding `List<String>` for these fields,
      so the batch Set/Add/Remove/Replace operations and the grid's `×N` badge
      have something to work with. That is a cross-cutting model change.
- [ ] **Album clustering (Ctrl+Shift+C)** for online lookup — group-by view
      over the custom-painted grid, collapsible group rows, fuzzy tolerance.
- [ ] **Undo failure reporting.** `UndoableCommand.undo()` returns `void`, so
      a rename that fails to move back is silently dropped from the stack
      while the UI shows it as done. Needs a result type and an error-log
      surface.
- [ ] **Timestamp-preservation failures are silent.** With the setting on, a
      failed `setLastModified` still reports the write as successful.
- [ ] **Per-apply "include preserved tags" override** in the lookup apply
      panel (the applicator already accepts the set per instance).
- [ ] Lookup applicators on background isolates with progress ports
- [ ] Signed installer (MSIX or Inno) bundling DLLs + VC++ runtime
- [ ] README screenshots

## Deferred / under consideration

- ReplayGain *calculation* (requires decoding audio — heavy dependency)
- Auto-update channel
- Plugin-style format extensions beyond the TagLib set
- Generic custom-frame support (TagLib surfaces arbitrary `TXXX` frames as
  `NAME_TXXX`; showing them all would need a display-name policy)
