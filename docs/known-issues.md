# Known Issues

Defects confirmed by evidence but not yet fixed. Each is either skipped in
CI with a pointer back here, or blocked on a platform not available in the
development environment.

## ID3v1 replace-in-place appends instead of replacing on Linux

**Status:** open, unfixed. Discovered by the `Test (ubuntu-latest)` CI job.

**Symptom**

`Id3v1Codec.writeToFile` is supposed to overwrite an existing trailing
ID3v1 block in place. On Linux the truncate does not take effect and the
block is appended a second time:

```
Expected: <545>   // 417-byte fixture + one 128-byte ID3v1 block
  Actual: <673>   // 417 + two blocks
```

`writeToFile` correctly reports `true` (it found a pre-existing tag), so
the failure is silent: the file grows by 128 bytes and now carries two
ID3v1 blocks, of which only the last is read back.

`Id3v1Codec.stripFromFile` uses the same
`openSync(FileMode.append)` + `truncateSync` sequence and **passes** on
Linux, which narrows the cause to something in the `writeToFile` path
rather than the append/truncate idiom generally.

**Code**

- `lib/shared/services/id3v1_codec.dart` — `writeToFile`
- `lib/shared/services/id3v1_codec.dart` — `_hasTag`
- `test/shared/services/tag_sync_service_test.dart` — "writeToFile appends
  then replaces in place", skipped on non-Windows hosts

**Why it is not fixed yet**

The root cause needs a Linux host to diagnose. The affected platform has
`ftruncate` available through the Dart `FileOps` binding exactly as on
Windows, and the Windows path passes, so the obvious hypotheses
("`O_APPEND` ignores the offset", "`truncateSync` is unsupported in append
mode") do not hold up — and rewriting ID3v1 write semantics on a guess
risks corrupting tags on the platform that currently works.

**How to reproduce**

```bash
flutter test test/shared/services/tag_sync_service_test.dart --plain-name \
  'writeToFile appends then replaces in place'
```

**Suspected area for the fix**

`writeToFile` opens the file in `FileMode.append` and *then* calls
`_hasTag`, which opens a second handle to the same path. Rewriting it to
use a single read/write handle (`FileMode.write` after an explicit length
check, or `FileMode.readWrite` with an explicit `setPositionSync`) would
remove the second handle and the mixed-mode semantics entirely, and is the
first thing to try once a Linux host is available.
