#!/usr/bin/env bash
set -euo pipefail

./Scripts/lint-format.sh
swift package resolve
swift build --build-tests
swift test
xcodebuild -project NotchHub.xcodeproj -scheme NotchHub -configuration Debug -destination 'platform=macOS' build
