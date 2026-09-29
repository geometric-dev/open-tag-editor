# Platform Support

Open Tag Editor reads and writes audio tags through the native
[TagLib](https://taglib.org/) C library (`taglib_c`). All three desktop
platforms are built and structurally verified on every CI run; only
Windows ships a committed prebuilt library, so macOS and Linux builds
require the `scripts/build-taglib.sh` step (automated in CI).

| Platform | Status | Reads | Writes | Notes |
|----------|--------|-------|--------|-------|
| Windows  | Supported | ✓ | ✓ | DLLs committed under `windows/`; `verify-release.ps1` runs in CI |
| Linux    | Supported | ✓ | ✓ | `libtaglib_c.so` built by `scripts/build-taglib.sh`; installed by `linux/CMakeLists.txt` |
| macOS    | Supported | ✓ | ✓ | `libtaglib_c.dylib` built by `scripts/build-taglib.sh`; embedded by the "Embed TagLib" Xcode phase |

Without the native library the app falls back to a pure-Dart reader
(limited format coverage) and **disables all writing**.

The loader searches these locations in order:

- Windows: `<exe dir>\taglib_c.dll`, then `<exe dir>\data\taglib_c.dll`
- macOS:   `<bundle>/Contents/Frameworks/libtaglib_c.dylib`
- Linux:   `<exe dir>/libtaglib_c.so`, then `<exe dir>/lib/libtaglib_c.so`,
           then the system soname `libtaglib_c.so`

## Building TagLib from source

`scripts/build-taglib.sh` does all of this for you and is what CI runs:

```bash
bash scripts/build-taglib.sh          # macOS -> macos/Frameworks/, Linux -> linux/lib/
```

TagLib builds quickly with CMake. Any recent 2.x release works; the script
defaults to `v2.1` and honours `TAGLIB_VERSION`, `TAGLIB_WORKDIR` and
`MACOS_ARCHS`. It builds the C bindings (`BUILD_SHARED_LIBS=ON`) against the
same architecture as your Flutter app, and renames TagLib's `tag_c` output
to the `libtaglib_c` name the app probes for.

<details>
<summary>Manual CMake commands (if you prefer to run them yourself)</summary>

### Linux

```bash
git clone --depth 1 --branch v2.1 https://github.com/taglib/taglib.git
cmake -S taglib -B taglib/build \
  -DBUILD_SHARED_LIBS=ON -DBUILD_BINDINGS=ON -DBUILD_TESTING=OFF
cmake --build taglib/build --config Release
# Output: taglib/build/taglib/libtag_c.so  -> rename to libtaglib_c.so
```

Place `libtaglib_c.so` in `linux/lib/`. `linux/CMakeLists.txt` installs it
next to the executable, which is the first path `NativeLibraryLoader`
probes. The bundle's `rpath` is `$ORIGIN/lib`, so the library's own
dependencies resolve from the same folder. Note that the bundled `.so`
links against your system's libstdc++; any current desktop distribution
satisfies this.

### macOS

```bash
git clone --depth 1 --branch v2.1 https://github.com/taglib/taglib.git
cmake -S taglib -B taglib/build \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DBUILD_SHARED_LIBS=ON -DBUILD_BINDINGS=ON -DBUILD_TESTING=OFF
cmake --build taglib/build --config Release
# Output: taglib/build/taglib/libtag_c.dylib
```

Place the result in `macos/Frameworks/libtaglib_c.dylib`. The "Embed TagLib"
Xcode build phase copies it into `Contents/Frameworks/` and re-signs it, so
you do not need to touch the built bundle yourself. For Apple Silicon use
`-DCMAKE_OSX_ARCHITECTURES=arm64`; for Intel use `x86_64`; for a universal
binary pass both separated by a semicolon (`MACOS_ARCHS`). The dylib must
match the app's architecture or `dlopen` will refuse it.

</details>

### Why not commit prebuilt binaries?

Prebuilt native blobs from unverified sources are a supply-chain risk. The
Windows DLLs are the one exception, and they predate the CI jobs. Every CI
run rebuilds TagLib from upstream source on the runner, so the macOS and
Linux artifacts in the Actions tab are traceable source -> artifact.

## Verifying

`scripts/verify-release.sh` (macOS/Linux) and `scripts/verify-release.ps1`
(Windows) assert that a built bundle has the native library in the loader's
primary search path, that its architecture matches the app binary, and that
it actually loads. Both run in CI on every push.

Launch the app and load a folder: files show a lock-free label icon when
tags are readable. If the title bar never enables Save after edits, the
native writer was not found — check the locations above for your OS.
