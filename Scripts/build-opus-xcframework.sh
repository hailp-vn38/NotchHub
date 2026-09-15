#!/usr/bin/env bash
set -euo pipefail

version=1.6.1
archive="${TMPDIR:-/tmp}/opus-${version}.tar.gz"
source_url="https://downloads.xiph.org/releases/opus/opus-${version}.tar.gz"
sha256="6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1"
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl --fail --location --silent --show-error --output "$archive" "$source_url"
printf '%s  %s\n' "$sha256" "$archive" | shasum -a 256 --check
tar -xzf "$archive" -C "$work"
cd "$work/opus-${version}"
CFLAGS='-mmacosx-version-min=14.0' ./configure --disable-shared --enable-static --disable-doc
make -j"$(sysctl -n hw.ncpu)"
make install DESTDIR="$work/stage"
rm -rf "$root/Vendor/Opus.xcframework"
xcodebuild -create-xcframework \
  -library "$work/stage/usr/local/lib/libopus.a" \
  -headers "$work/stage/usr/local/include" \
  -output "$root/Vendor/Opus.xcframework"
