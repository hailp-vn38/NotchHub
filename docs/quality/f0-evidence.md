# F0 Evidence

**Status:** Local checks passed; pull-request CI run pending
**Phase:** F0 — Bootstrap and architecture
**Recorded:** 2026-09-14
**Scope:** Repository verification seam on the F0 foundation checkout

## Local verification result

The local composite command below completed with exit status 0 on 2026-09-14 with Xcode 26.0.1,
matching [`.xcode-version`](../../.xcode-version). It is necessary evidence for F0, but it does
not close the F0 gate until the configured pull-request workflow has a recorded green run.

```bash
VERIFY_BASE_REF=HEAD^ ./Scripts/verify.sh
```

The command exercised these checks with their repository commands:

| Gate | Command | Result |
|---|---|---|
| Pinned toolchain | `./Scripts/check-toolchain.sh` | Passed |
| Formatter | `./Scripts/lint-format.sh` | Passed |
| Pure-domain import boundary | `./Scripts/check-domain-boundary.sh` | Passed; `NotchDomain` imports neither SwiftUI nor AppKit |
| Verification-check behavior | `./Tests/Scripts/verification-checks.sh` | Passed; broken Markdown anchors and a bearer-token fixture were rejected as expected |
| Dependency resolution and package build | `swift package resolve` and `swift build --build-tests` | Passed |
| Pure-domain unit tests | `swift test` | Passed; 3 tests, 0 failures |
| Application host build | `xcodebuild -project NotchHub.xcodeproj -scheme NotchHub -configuration Debug -destination 'platform=macOS' build` | Passed |
| Repository Markdown links | `./Scripts/check-markdown-links.sh` | Passed |
| Changed-file secret scan | `./Scripts/check-changed-secrets.sh` | Passed |

## Clean-worktree build result

The same command was also run in a newly created detached Git worktree on 2026-09-14, with no
existing `.build` directory or untracked workspace files. It completed with exit status 0 using
the F0 candidate commit and `VERIFY_BASE_REF=ca7fd38`. SwiftPM compiled the package test bundle
from source, all 3 pure-domain tests passed, and the Xcode application build succeeded. This is
the recorded clean-build evidence; it is independent of the developer worktree.

## CI evidence

[`pull-request-verification.yml`](../../.github/workflows/pull-request-verification.yml) runs the
same `./Scripts/verify.sh` seam for every pull request, after selecting Xcode 26.0.1 and setting
`VERIFY_BASE_REF` to the pull-request base SHA. A green pull-request run (with its URL or run ID)
must be added here before F0 is closed. No external GitHub run has been observed for this record.

## F0 boundary retained

This evidence proves the F0 repository foundation only. It does not prove F1 app lifecycle,
F2 Notch surface behavior, permissions, IPC, performance, signing, or manual macOS QA; those
remain later-phase gates.
