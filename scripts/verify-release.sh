#!/usr/bin/env bash
#
# POSIX counterpart to scripts/verify-release.ps1.  Verifies that a macOS or
# Linux release bundle is structurally correct:
#   1. The native TagLib library sits where NativeLibraryLoader probes first
#      (<app>/Contents/Frameworks for macOS, next to the binary for Linux).
#   2. It carries the expected architecture.
#   3. It actually loads (so a missing transitive dependency, e.g. libstdc++
#      on Linux, is caught here rather than at runtime with writing
#      silently disabled).
#
# Usage: bash scripts/verify-release.sh [--bundle <path>]
set -uo pipefail

BUNDLE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --bundle) BUNDLE="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$BUNDLE" ]; then
  case "$(uname -s)" in
    Darwin) BUNDLE="$(pwd)/build/macos/Build/Products/Release/open_tag_editor.app" ;;
    *)      BUNDLE="$(pwd)/build/linux/x64/release/bundle" ;;
  esac
fi

failures=()
ok()      { echo "OK   $1"; }
fail()    { failures+=("$1"); }

if [ "$(uname -s)" = "Darwin" ]; then
  exe="$BUNDLE/Contents/MacOS/open_tag_editor"
  lib="$BUNDLE/Contents/Frameworks/libtaglib_c.dylib"
  expected_arch="arm64 or x86_64"
else
  exe="$BUNDLE/open_tag_editor"
  lib="$BUNDLE/libtaglib_c.so"
  expected_arch="x86_64 or aarch64"
fi

if [ ! -f "$exe" ]; then
  if [ "$(uname -s)" = "Darwin" ]; then
    hint="flutter build macos --release"
  else
    hint="flutter build linux --release"
  fi
  echo "error: no executable at $exe - build first ($hint)" >&2
  exit 1
fi

# 1. Native library in the loader's primary search path.
if [ -f "$lib" ]; then
  ok "TagLib library present at $(basename "$(dirname "$lib")")/$(basename "$lib")"
else
  fail "TagLib library missing at $lib - writes will be disabled (run scripts/build-taglib.sh)"
fi

# 2. Architecture matches the app binary.
if [ -f "$exe" ] && [ -f "$lib" ]; then
  if command -v lipo >/dev/null 2>&1; then
    app_arch="$(lipo -archs "$exe" 2>/dev/null)"
    lib_arch="$(lipo -archs "$lib" 2>/dev/null)"
    overlap="$(comm -12 <(tr ' ' '\n' <<<"$app_arch" | sort -u) \
                        <(tr ' ' '\n' <<<"$lib_arch"  | sort -u) | tr -d '[:space:]')"
    if [ -n "$overlap" ]; then
      ok "architecture overlap between app ($app_arch) and library ($lib_arch): $overlap"
    else
      fail "architecture mismatch: app is $app_arch, library is $lib_arch (expected $expected_arch)"
    fi
  else
    lib_arch="$(readelf -h "$lib" 2>/dev/null | awk -F: '/Machine/{gsub(/^ +/,"",$2); print $2}')"
    app_arch="$(readelf -h "$exe" 2>/dev/null | awk -F: '/Machine/{gsub(/^ +/,"",$2); print $2}')"
    if [ "$lib_arch" = "$app_arch" ]; then
      ok "architecture matches: $app_arch"
    else
      fail "architecture mismatch: app is '$app_arch', library is '$lib_arch' (expected $expected_arch)"
    fi
  fi
fi

# 3. The library actually resolves all of its own dependencies.
if [ -f "$lib" ]; then
  if command -v otool >/dev/null 2>&1; then
    deps="$(otool -L "$lib" | tail -n +2 | awk '{print $1}')"
    unresolved=""
    # Fed via a heredoc rather than a pipeline: this is a subshell, and the
    # pipeline form is not parseable by the bash 3.2 that macOS ships.
    while IFS= read -r dep; do
      if [ -z "$dep" ]; then
        continue
      fi
      case "$dep" in
        @*)
          # @rpath / @loader_path: resolved through the binary's rpath.
          continue
          ;;
        /usr/lib/* | /System/*)
          # System and SDK libraries. otool prints absolute /usr/lib paths
          # for these, but on a build machine the SDK entries are linker
          # stubs rather than real files, so a filesystem test would report
          # a false failure. They are guaranteed present at load time.
          continue
          ;;
        /*)
          if [ ! -e "$dep" ]; then
            unresolved="$unresolved $dep"
          fi
          ;;
      esac
    done <<EOF
$deps
EOF
    if [ -n "$unresolved" ]; then
      fail "unresolved library dependencies:$unresolved"
    else
      ok "all dylib dependencies resolve"
    fi
  else
    if ldd "$lib" >/dev/null 2>&1 && ! ldd "$lib" 2>/dev/null | grep -q 'not found'; then
      ok "all shared-object dependencies resolve"
    else
      fail "unresolved shared-object dependencies: $(ldd "$lib" 2>/dev/null | grep 'not found' | tr '\n' ' ')"
    fi
  fi
fi

echo ""
if [ ${#failures[@]} -gt 0 ]; then
  for f in "${failures[@]}"; do echo "FAIL $f" >&2; done
  exit 1
fi

echo "Release bundle verification PASSED"
