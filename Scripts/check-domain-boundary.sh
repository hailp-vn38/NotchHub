#!/usr/bin/env bash
set -euo pipefail

if rg -n '^import (AppKit|SwiftUI)$' Packages/NotchDomain/Sources; then
  echo 'NotchDomain must not import AppKit or SwiftUI.' >&2
  exit 1
fi
