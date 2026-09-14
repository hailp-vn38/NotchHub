#!/usr/bin/env bash
set -euo pipefail

xcrun swift-format format --recursive --in-place --configuration .swift-format Apps Packages Tests
