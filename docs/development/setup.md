# Development Setup
## NotchHub — macOS Development Environment

**Status:** Draft v0.1  
**Owner:** Development / Architecture  
**Last updated:** 2026-09-14
**Location:** `docs/development/setup.md`  
**Related documents:** [README](../../README.md), [Vision](../product/vision.md), [Architecture Overview](../architecture/overview.md), [Testing Strategy](../quality/testing-strategy.md), [Apple APIs](../references/apple-apis.md)

---

## 1. Purpose

This document defines the reproducible development environment and workflow for NotchHub.

The goal is that a developer—or an AI coding agent operating under the repository instructions—can
clone the project, build it, run the F0 pure-domain tests, and perform the foundation quality
checks without undocumented local steps.

NotchHub is a macOS application. UI/window/lifecycle behavior must be tested on macOS, not only in a generic CI environment. The foundation targets macOS 14+ and uses SwiftUI, AppKit, Swift Concurrency, Observation, Keychain, OSLog, and local IPC.

---

## 2. Development scope

This setup covers the implemented F0 foundation:

- Swift/Xcode development for the NotchHub macOS app.
- Swift Package Manager package development.
- Pure-domain unit tests.
- The placeholder macOS application-host build.
- Documentation/ADR workflow.

Local IPC, `notchctl`, lifecycle QA, and performance profiling are later-phase work, not F0 setup
requirements. F1 adds app-shell manual QA; use the explicit F1 matrix in
[`f1-evidence.md`](../quality/f1-evidence.md) when that phase is implemented.

## 3. Required environment

### 3.1 Hardware

Minimum development environment:

- A Mac capable of running the supported macOS/Xcode combination.
- A built-in MacBook display is strongly preferred for real Notch testing.
- An external display is useful for lifecycle/geometry testing but is not required for the first build.

### 3.2 Operating system

- macOS 14 Sonoma or newer.
- Use a supported macOS version matching the selected Xcode release.
- Record the OS version in bug reports and performance results.

### 3.3 Toolchain

- Xcode 26.0.1, pinned in [`.xcode-version`](../../.xcode-version) and selected by the matching
  pull-request workflow. It provides Swift 6 and Swift Package Manager.
- Swift Package Manager (bundled with Swift/Xcode).
- Git.
- Terminal shell available through macOS.
- Apple Developer account only when signing, entitlements, device testing, or notarization requires it.

The F0 scaffold must pin one Xcode version and use the matching CI image. Do not assume that the latest Xcode is supported; the pin and CI workflow are the source of truth.

### 3.4 Optional tools

Use only tools declared by repository policy:

- One checked-in formatter selected by the F0 scaffold.
- Optional SwiftLint only after a small checked-in rule set is adopted.
- Markdown link checker.
- Secret scanner.
- Instruments/Xcode Organizer.

Optional tools must not be required to compile or run the core project unless they are added to the documented bootstrap process.

---

## 4. Repository checkout

```bash
git clone <repository-url>
cd NotchHub
```

If the repository uses submodules or Git LFS in the future, the exact commands must be documented here before they become required.

### Verify repository state

```bash
git status
git branch --show-current
git log -1 --oneline
```

Do not begin work with uncommitted changes from another task unless they are documented and intentional.

---

## 5. Expected repository structure

```text
NotchHub/
├── Package.swift
├── NotchHub.xcodeproj/
├── Apps/NotchHubApp/
├── Packages/
├── Tests/
├── Scripts/
└── docs/
```

`Modules/`, `Tools/notchctl`, a menu-bar shell, and a Notch surface are not part of the F0 checkout.

---

## 6. First build

### 6.1 Open in Xcode

```bash
open NotchHub.xcodeproj
```

Select the `NotchHub` scheme and a macOS destination.

### 6.2 Command-line build

The checked-in app host uses the `NotchHub` scheme:

```bash
xcodebuild \
  -project NotchHub.xcodeproj \
  -scheme NotchHub \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

### 6.3 Run package tests

```bash
swift test
```

F0 has no app-level test bundle yet. The package test target verifies the public package boundary; pull-request CI runs the complete repository verification workflow.

### 6.4 Swift Package Manager commands

For package-only development, use the package commands documented by the repository:

```bash
swift package resolve
swift build
swift test
```

### 6.5 Format Swift sources

The pinned Xcode toolchain provides `swift-format`. Check formatting before committing:

```bash
./Scripts/lint-format.sh
```

To apply formatting:

```bash
./Scripts/format.sh
```

### 6.6 Verify the F0 foundation

Run the same composite verification seam that pull-request CI runs. Set `VERIFY_BASE_REF` to the commit, branch, or remote-tracking branch that your work will merge into; the secret check scans only content changed from that base.

```bash
VERIFY_BASE_REF=main ./Scripts/verify.sh
```

The command checks the pinned Xcode version, Swift formatting, the pure-domain import boundary,
package dependency resolution/build/tests, the placeholder app build, local Markdown links, and
secret-like values added in changed files. CI invokes this exact command with the pull-request base
commit as `VERIFY_BASE_REF`. See the recorded [F0 evidence](../quality/f0-evidence.md) for the
passing gate and its scope.

Do not use `swift run` to launch the macOS app unless the project explicitly supports that target; the native app target normally runs through Xcode/xcodebuild.

---

## 7. Initial app run

On first run, the expected F0 behavior is:

- The app opens a normal window titled `NotchHub`.
- The window shows the `Foundation scaffold` placeholder.
- No menu-bar utility, Notch surface, Settings, Diagnostics, permission request, module registration,
  or IPC listener is present.

### First-run checks

1. Launch the `NotchHub` scheme from Xcode.
2. Confirm the `Foundation scaffold` placeholder appears.
3. Quit and relaunch the application.

Menu-bar, Notch-surface, lifecycle, permission, and IPC checks begin in their respective later
phases.

---

## 8. Local IPC development

### 8.1 Default boundary

Local IPC is Unix socket and/or loopback-only HTTP/WebSocket. It must not bind to LAN interfaces.

Expected routes when implemented:

```text
GET  /v1/health
GET  /v1/status
POST /v1/events
POST /v1/actions/{actionID}
WS   /v1/stream
```

### 8.2 `notchctl`

Intended commands:

```bash
notchctl health
notchctl status
notchctl emit surface.compact --title "Foundation test" --message "IPC is working"
notchctl action app.openSettings
notchctl action surface.toggleDebugOverlay
```

The actual command names/options are defined by the CLI implementation. Never add a command that accepts arbitrary shell/script/executable text.

### 8.3 IPC token

- Store local IPC credentials in Keychain/protected storage according to `data-persistence.md`.
- Do not put tokens in shell history, repository files, logs, screenshots, issue reports, or diagnostics exports.
- If a token is exposed, revoke/rotate it and record a security incident as appropriate.

### 8.4 Development-only event injection

Development builds may expose deterministic test events or an internal injector. The injector must:

- Be disabled or restricted in release builds.
- Use the same event schema validator as real IPC.
- Use synthetic data.
- Never accept raw commands or undeclared targets.

---

## 9. Permissions during development

The foundation should run with no sensitive permissions granted.

### Permission testing

Use a test adapter for unit/integration tests. Use a signed development/release-like build for real macOS permission testing.

Test capability states:

```text
notDetermined
authorized
denied
restricted
unavailable
```

### Rules

- Do not grant permissions globally just to make tests pass.
- Record which permission was enabled for a manual test.
- Reset/revoke permission between scenarios where the test depends on the initial state.
- Do not capture real microphone, camera, screen, clipboard, calendar, or transcript data for fixtures.
- M1 display-only Xiaozhi testing must not require Microphone permission.

---

## 10. Signing and entitlements

### Development

- Local debug runs may use Xcode development signing as required.
- Do not commit personal Team IDs, signing certificates, provisioning profiles, or private keys.
- Store secrets/configuration outside the repository.

### Release-like testing

Before beta/release, test a signed/notarized-like build because permission, Keychain, sandbox, launch-at-login, and helper behavior may differ from an unsigned debug run.

Document when implementation adds:

- Entitlements.
- Usage-description keys.
- Sandboxing changes.
- Keychain access-group changes.
- Login-item/helper signing.
- Private/privileged API use.

Any such change requires security/release review and usually an ADR.

---

## 11. Testing workflow

### Fast local loop

```text
Edit small change
    ↓
Format/lint changed files
    ↓
Run focused package tests
    ↓
Build app
    ↓
Run relevant integration/UI/manual check
    ↓
Update docs/ADR if behavior changed
```

### Foundation checks

```bash
swift package resolve
swift build
swift test

# Project-specific xcodebuild commands are the CI source of truth.
xcodebuild -project NotchHub.xcodeproj -scheme NotchHub test
```

### When to run Instruments

Profile when changing:

- `NSPanel`/animation/windowing.
- Observation/state projections.
- High-rate EventBus/event adapters.
- Timers/global event monitors.
- Persistence/log/cache behavior.
- IPC streaming/backpressure.
- Module start/stop or background work.
- Permission-dependent capture/audio.

Required scenarios are documented in [`performance.md`](../architecture/performance.md) and [`testing-strategy.md`](../quality/testing-strategy.md).

---

## 12. Documentation workflow

Before starting implementation:

- Read `README.md`.
- Read `docs/product/vision.md`, `roadmap.md`, and `requirements.md`.
- Read the relevant architecture/component document.
- Check active ADRs.
- Check security/performance/permission implications.

When behavior changes:

- Update the relevant documentation in the same change.
- Add/update an ADR for durable architecture decisions.
- Add/update acceptance tests and fixtures.
- Add module documentation before merging a module.

---

## 13. Environment and secrets

### Do not commit

- API keys/tokens/passwords.
- Keychain exports.
- Signing certificates/private keys.
- Provisioning profiles containing sensitive material.
- Real user transcripts, clipboard/history, calendar details, file content, audio, camera frames, or screen captures.
- Machine-specific absolute paths unless deliberately sanitized.
- Large Instruments artifacts unless the repository policy explicitly permits them.

### Environment variables

If environment variables are required in the future:

- Document name, purpose, format, and sensitivity in this file.
- Provide a safe example file with placeholders.
- Validate at startup with clear errors.
- Never print secret values.
- Avoid requiring secrets for foundation unit tests.

---

## 14. Troubleshooting

### App does not appear in the menu bar

- Confirm the app process is running.
- Check `os_log`/Diagnostics for startup failure.
- Verify the app activation policy/menu-bar scene is configured.
- Quit/relaunch and inspect single-instance behavior.
- Use a release-like build if behavior differs from Debug.

### Notch surface is missing

- Open Diagnostics from the menu bar.
- Inspect surface state, selected display, calculated frame, suppression reason, and recovery count.
- Confirm the built-in display is available.
- Test with debug overlay enabled.
- Use “Restart App Shell” rather than force-killing the process first. “Restart Runtime” is only applicable after F7 introduces `ModuleRuntime`.

### Permission prompt does not appear

- Confirm the feature is actually enabled and explicitly invoked.
- Check Permission Center status.
- Confirm the module declared the capability.
- Verify the app is using a supported signed configuration.
- Open System Settings manually and inspect Privacy & Security.
- Do not add a retry loop or request permission from a view.

### Settings failed to load

- Open Diagnostics.
- Check schema version/migration error.
- Preserve/copy the sanitized diagnostic report.
- Use the scoped reset action if appropriate.
- Do not delete Keychain credentials unless the user explicitly selects credential reset.

### IPC request rejected

Check:

- App is running and IPC is ready.
- Correct transport/socket/path.
- Authentication token is valid and not revoked.
- Client/source is allowed for the operation.
- Protocol version and payload schema are current.
- Payload is within size/rate limits.
- Action ID is registered/available.

Never solve IPC rejection by exposing the service to the LAN or accepting raw commands.

### Tests fail only on a particular Mac

Record:

- macOS version.
- Xcode version.
- Mac model/architecture.
- Display configuration/scale.
- Permission state.
- Signed/unsigned build status.
- Exact test and diagnostic output.

Window/lifecycle tests may require a real macOS environment and must not be “fixed” by weakening core safety rules.

---

## 15. Definition of a ready development environment

A developer environment is ready when:

- Project builds from a clean clone.
- Unit/package tests pass.
- The app launches as a menu-bar utility.
- Settings and Diagnostics open.
- Notch placeholder surface responds to basic interactions.
- No unexpected sensitive permission prompts occur.
- `notchctl health/status` works when IPC is implemented.
- Documentation/ADR links resolve.
- No secrets are present in the working tree or test fixtures.

---

## 16. Summary

A reproducible NotchHub setup is intentionally small: macOS, Xcode/Swift, Git, documented project commands, and the Apple tools needed to test the native surface. The foundation should run without sensitive permissions, external services, hardware toolchains, or hidden setup steps.

Every future requirement for a new permission, entitlement, service, API key, external process, or network transport must be documented and reviewed before it becomes a developer prerequisite.
