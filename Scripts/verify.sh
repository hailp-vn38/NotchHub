#!/usr/bin/env bash
set -euo pipefail

./Scripts/check-toolchain.sh
./Scripts/lint-format.sh
./Scripts/check-domain-boundary.sh
./Tests/Scripts/verification-checks.sh
swift package resolve
swift build --build-tests
swift test
xcodebuild -project NotchHub.xcodeproj -scheme NotchHub -configuration Debug -destination 'platform=macOS' build
./Scripts/check-markdown-links.sh
./Scripts/check-changed-secrets.sh
