# Roadmap

Direction agreed for the 0.2 → 0.3 lines. 0.2 (current) is the
"Trust & Quality" release: see CHANGELOG.

## 0.2.x — hardening

- [x] Run `scripts/verify-release.ps1` in CI on a built artifact (not just locally)
- [x] Bundle or auto-install VC++ runtime in the Windows installer
      (`scripts/bundle-crt.ps1`; the installer itself is still 0.3 work)
- [ ] Surface "native TagLib missing — writes disabled" as a status-bar state
      instead of silent degradation (architect follow-up from platform review)
- [ ] Golden tests for the data grid; large-library (10k rows) perf pass
- [ ] Wire lookup *apply* results into the error log per-file (today only
      whole-step failures are logged)

## 0.3.0 — feature wave

- [ ] Multi-value tag fields (multiple artists/genres) end-to-end:
      model, grid display, panel editor, TagLib mapping
- [ ] ReplayGain: read/display RG info, preserve verified (done), add
      optional clear/normalize actions
- [ ] Drag-reorder column headers (menu-based reorder shipped in 0.2)
- [ ] Lookup applicators on background isolates with progress ports
- [ ] Tag deletion & cleanup PRD (strip ID3v1, remove empty frames)
- [x] macOS/Linux CI jobs that build TagLib and attach native artifacts;
      Xcode copy-phase + Linux packaging so both platforms ship like Windows
- [ ] Installer (MSIX or Inno) bundling DLLs + VC++ runtime, signed builds
- [ ] Accessibility audit: Semantics coverage beyond tooltips, high-contrast
      theme, keyboard-only walkthrough
- [ ] Empty-state/onboarding polish; README screenshots

## Deferred / under consideration

- ReplayGain calculation (requires decoding audio — heavy dependency)
- Auto-update channel
- Plugin-style format extensions beyond the TagLib set
