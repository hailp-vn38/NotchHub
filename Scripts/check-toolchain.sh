#!/usr/bin/env bash
set -euo pipefail

expected_version="$(<.xcode-version)"
actual_version="$(xcodebuild -version | sed -n 's/^Xcode //p' | head -n 1)"

if [[ "$actual_version" != "$expected_version" ]]; then
  echo "Expected Xcode $expected_version from .xcode-version; found ${actual_version:-unknown}." >&2
  exit 1
fi
