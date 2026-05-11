# TagLib Native Library (macOS)

Place `libtaglib_c.dylib` (universal binary: x64 + ARM64) in this directory.

## Build Instructions

1. Clone TagLib: `git clone https://github.com/taglib/taglib.git`
2. Build for both architectures:
   ```bash
   # x64
   cmake -B build-x64 -DCMAKE_OSX_ARCHITECTURES=x86_64 -DBUILD_SHARED_LIBS=ON
   cmake --build build-x64
   
   # ARM64
   cmake -B build-arm64 -DCMAKE_OSX_ARCHITECTURES=arm64 -DBUILD_SHARED_LIBS=ON
   cmake --build build-arm64
   ```
3. Create universal binary:
   ```bash
   lipo -create build-x64/taglib/libtag_c.dylib build-arm64/taglib/libtag_c.dylib -output libtaglib_c.dylib
   ```
4. Place the resulting `libtaglib_c.dylib` in this directory.

The app's `NativeLibraryLoader` expects to find it at `<app_bundle>/Contents/Frameworks/libtaglib_c.dylib`.
