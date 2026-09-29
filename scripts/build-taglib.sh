#!/usr/bin/env bash
#
# Builds the TagLib C bindings from source and installs them where the
# Flutter build expects them.  Used by the macOS and Linux CI jobs so no
# prebuilt binary is ever committed (see docs/platforms.md).
#
#   macOS:  -> macos/Frameworks/libtaglib_c.dylib  (embedded by the
#             "Embed TagLib" Xcode build phase)
#   Linux:  -> linux/lib/libtaglib_c.so            (installed next to the
#             executable by linux/CMakeLists.txt)
#
# Environment overrides:
#   TAGLIB_VERSION  TagLib git tag to build (default: v2.1)
#   TAGLIB_WORKDIR  Scratch directory for the clone/build (default: .dart_tool/taglib)
#   MACOS_ARCHS     Comma-separated archs for a universal binary
#                   (default: "x86_64;arm64")
#
# Usage: bash scripts/build-taglib.sh
set -euo pipefail

TAGLIB_VERSION="${TAGLIB_VERSION:-v2.1}"
TAGLIB_WORKDIR="${TAGLIB_WORKDIR:-$(pwd)/.dart_tool/taglib}"
MACOS_ARCHS="${MACOS_ARCHS:-x86_64;arm64}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$TAGLIB_WORKDIR/taglib"

if ! command -v cmake >/dev/null 2>&1; then
  echo "error: cmake is required" >&2
  exit 1
fi

mkdir -p "$TAGLIB_WORKDIR"

if [ ! -d "$SRC_DIR/.git" ]; then
  echo "==> Cloning TagLib $TAGLIB_VERSION"
  rm -rf "$SRC_DIR"
  # TagLib vendors utfcpp as the 3rdparty/utfcpp submodule and will not
  # configure without it, so the clone must recurse.
  git clone --depth 1 --recurse-submodules --shallow-submodules \
    --branch "$TAGLIB_VERSION" \
    https://github.com/taglib/taglib.git "$SRC_DIR"
else
  echo "==> Reusing existing TagLib clone at $SRC_DIR"
fi

if [ ! -f "$SRC_DIR/3rdparty/utfcpp/CMakeLists.txt" ] &&
   [ ! -d "$SRC_DIR/3rdparty/utfcpp/include" ]; then
  echo "==> Fetching TagLib submodules (utfcpp)"
  git -C "$SRC_DIR" submodule update --init --depth 1 --recursive
fi

# TagLib 2.x names the C-binding library tag_c; the app expects
# libtaglib_c, so the output is renamed below.
build_slice() {
  local arch="$1" build_dir="$2"
  echo "==> Building TagLib ($arch)"
  cmake -S "$SRC_DIR" -B "$build_dir" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_BINDINGS=ON \
    -DBUILD_TESTING=OFF \
    -DBUILD_EXAMPLES=OFF >/dev/null
  cmake --build "$build_dir" --config Release --parallel >/dev/null
}

# TagLib 2.x names the C-binding target `tag_c`, but the on-disk output
# varies by platform and by whether a version suffix is applied:
#   Linux  libtag_c.so  (or libtag_c.so.1)
#   macOS  libtag_c.dylib, libtag_c.<soversion>.dylib, or libtag_c.<ver>.dylib
# and it may sit either in the build root or under taglib/. Prefer an
# unversioned name, then fall back to any match.
find_binding() {
  local dir="$1"
  local candidates
  candidates="$(find "$dir" -type f \
      \( -name 'libtag_c*.dylib' -o -name 'tag_c*.dylib' \
         -o -name 'libtag_c*.so*'  -o -name 'tag_c*.so*' \) 2>/dev/null | sort)"

  if [ -z "$candidates" ]; then
    echo ""
    return
  fi

  # Exact unversioned names first.
  local exact
  exact="$(printf '%s\n' "$candidates" | grep -E '/(lib)?tag_c\.(dylib|so)$' || true)"
  if [ -n "$exact" ]; then
    printf '%s\n' "$exact" | head -n 1
  else
    printf '%s\n' "$candidates" | head -n 1
  fi
}

# Printed when discovery fails, so the CI log shows what was actually built
# instead of just "not found".
dump_binding_candidates() {
  echo "--- files CMake produced under $1 matching *tag*:" >&2
  find "$1" -type f -iname '*tag*' 2>/dev/null | head -n 30 >&2
}

case "$(uname -s)" in
  Darwin)
    slices=()
    rm -rf "$TAGLIB_WORKDIR"/build-*
    IFS=';' read -ra arch_list <<< "$MACOS_ARCHS"
    for arch in "${arch_list[@]}"; do
      build_slice "$arch" "$TAGLIB_WORKDIR/build-$arch"
      found="$(find_binding "$TAGLIB_WORKDIR/build-$arch")"
      if [ -z "$found" ]; then
        dump_binding_candidates "$TAGLIB_WORKDIR/build-$arch"
        echo "error: could not locate the TagLib C binding in build-$arch" >&2
        exit 1
      fi
      echo "==> $arch binding: $found"
      slices+=("$found")
    done

    mkdir -p "$REPO_ROOT/macos/Frameworks"
    out="$REPO_ROOT/macos/Frameworks/libtaglib_c.dylib"
    if [ "${#slices[@]}" -eq 1 ]; then
      cp -f "${slices[0]}" "$out"
    else
      lipo -create "${slices[@]}" -output "$out"
    fi
    # The embed build phase re-signs; strip the local one first so it never
    # carries a stale signature into the bundle.
    codesign --remove-signature "$out" 2>/dev/null || true
    echo "==> macOS dylib: $out"
    lipo -info "$out"
    ;;

  Linux)
    build_slice "native" "$TAGLIB_WORKDIR/build-linux"
    found="$(find_binding "$TAGLIB_WORKDIR/build-linux")"
    if [ -z "$found" ]; then
      dump_binding_candidates "$TAGLIB_WORKDIR/build-linux"
      echo "error: could not locate the TagLib C binding" >&2
      exit 1
    fi
    echo "==> binding: $found"
    mkdir -p "$REPO_ROOT/linux/lib"
    out="$REPO_ROOT/linux/lib/libtaglib_c.so"
    cp -f "$found" "$out"
    strip --strip-unneeded "$out" 2>/dev/null || true
    echo "==> Linux library: $out"
    ;;

  *)
    echo "error: unsupported host '$(uname -s)' - this script is for macOS and Linux" >&2
    exit 1
    ;;
esac
