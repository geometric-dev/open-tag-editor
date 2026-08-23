# Platform Support

Open Tag Editor reads and writes audio tags through the native
[TagLib](https://taglib.org/) C library (`taglib_c`). The application ships
with working packaging for **Windows**; **macOS and Linux are experimental**
and require you to provide the native library yourself until automated
packaging lands.

| Platform | Status | Reads | Writes | Notes |
|----------|--------|-------|--------|-------|
| Windows  | Supported | ✓ | ✓ | DLLs bundled by `flutter build`; run `scripts/verify-release.ps1` |
| Linux    | Experimental | ✓* | ✓* | Place `libtaglib_c.so` next to the executable or in `lib/` beside it |
| macOS    | Experimental | ✓* | ✓* | Place `libtaglib_c.dylib` in `Contents/Frameworks/` |

\* Requires the steps below. Without the native library the app falls back
to a pure-Dart reader (limited format coverage) and **disables all writing**.

The loader searches these locations in order:

- Windows: `<exe dir>\taglib_c.dll`, then `<exe dir>\data\taglib_c.dll`
- macOS:   `<bundle>/Contents/Frameworks/libtaglib_c.dylib`
- Linux:   `<exe dir>/libtaglib_c.so`, then `<exe dir>/lib/libtaglib_c.so`,
           then the system soname `libtaglib_c.so`

## Building TagLib from source

TagLib builds quickly with CMake. Any recent 2.x release works; build the
C bindings (`BUILD_SHARED_LIBS=ON`) against the same architecture as your
Flutter app.

### Linux

```bash
git clone --depth 1 --branch v2.0 https://github.com/taglib/taglib.git
cmake -S taglib -B taglib/build \
  -DBUILD_SHARED_LIBS=ON -DBUILD_BINDINGS=ON -DBUILD_TESTING=OFF
cmake --build taglib/build --config Release
# Output: taglib/build/libtaglib.so  -> rename/copy to libtaglib_c.so
cp taglib/build/libtaglib.so libtaglib_c.so
```

Place `libtaglib_c.so` next to `open_tag_editor` (or in a `lib/`
subdirectory of it). Note the bundled `.so` links against your system's
libstdc++; any current desktop distribution satisfies this.

### macOS

```bash
git clone --depth 1 --branch v2.0 https://github.com/taglib/taglib.git
cmake -S taglib -B taglib/build \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DBUILD_SHARED_LIBS=ON -DBUILD_BINDINGS=ON -DBUILD_TESTING=OFF
cmake --build taglib/build --config Release
# Output: taglib/build/libtaglib_c.dylib
```

Copy `libtaglib_c.dylib` into the app bundle:

```bash
cp libtaglib_c.dylib \
  build/macos/Build/Products/Release/open_tag_editor.app/Contents/Frameworks/
```

For Apple Silicon use `-DCMAKE_OSX_ARCHITECTURES=arm64`; for Intel use
`x86_64`; for a universal binary pass both separated by a semicolon. The
dylib must match the app's architecture or `dlopen` will refuse it.

### Why not commit prebuilt binaries?

Prebuilt native blobs from unverified sources are a supply-chain risk, and
per-platform CI artifact building is planned but not yet wired up. Building
one small C++ library locally takes about a minute and keeps the trust chain
yours.

## Verifying

Launch the app and load a folder: files show a lock-free label icon when
tags are readable. If the title bar never enables Save after edits, the
native writer was not found — check the locations above for your OS.
