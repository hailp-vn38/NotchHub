# F4 Typed Settings Evidence

**Status:** Passed
**Owner:** Architecture / Quality
**Last updated:** 2026-09-15
**Scope:** Typed settings, migration, atomic persistence, reset, sanitized import/export, and recovery

## Contract under test

- `AppSettings` v1 owns only Appearance and Notch Behavior configuration: theme, Reduced Motion
  override, hover delay (`150`/`300`/`500` ms), and auto-collapse timeout (`2`/`3`/`5` seconds).
- Full-screen suppression remains an invariant and is not persisted by F4 v1.
- `SettingsBackend` stores one versioned snapshot in Application Support and atomically replaces it.
- Secrets remain in Keychain and never enter a settings snapshot, ordinary reset, import, export,
  fixture, or diagnostics payload.
- A valid F4 import replaces the complete F4-owned snapshot atomically after validation.
- Corrupt current-schema data moves to quarantine (at most three 1 MiB files; 3 MiB total), then
  recovers to safe defaults with a typed Settings recovery outcome.
- A newer unknown schema enters read-only recovery and its bytes are not overwritten.
- F4 does not create concrete shortcut, module, or diagnostics settings. Their owners are F6, F7,
  and F9.

## Phase precondition

F2's prerequisite is confirmed by the maintainer for this implementation run. F2 retains its own
evidence record; this F4 acceptance does not infer or rewrite that separate native-QA matrix.

## Required automated evidence

| Check | Required evidence | Result |
|---|---|---|
| Defaults and validation | Unit tests for every F4 v1 field and invalid value | **PASS** — `swift test` |
| Migration | Before/after fixture for every released schema version | **PASS** — v0 fixture and failed-write preservation |
| Corruption recovery | Fixtures quarantine original bytes, enforce 3-file/3 MiB rotation, and recover without preventing startup | **PASS** — `swift test` |
| Forward schema | Newer-schema fixture produces read-only recovery and preserves bytes | **PASS** — `swift test` |
| Atomic persistence | Simulated interrupted/failed replacement retains last known-good snapshot | **PASS** — `swift test`, including failed mutation and import replacement |
| Import/export | Export excludes secrets; invalid import changes nothing; valid import atomically replaces F4 scope | **PASS** — `swift test` (64 tests): export has only `schemaVersion`, Appearance, and Notch Behavior; an extra credential/future-scope key is rejected before replacement |
| Reset | Normal reset excludes credentials; credential deletion remains a distinct confirmed flow | **PASS (F4 boundary)** — `swift test`: reset writes only safe F4 defaults; F4 has no Secret field or credential-deletion operation. Credential deletion remains an out-of-scope, separately confirmed Secret-owner flow. |
| Boundary | Views do not access raw persistence APIs or Keychain | **PASS** — typed store/model projection and repository checks |

## Manual macOS evidence

Record the macOS version and build used to confirm:

1. F4 settings survive an app relaunch.
2. A recovery outcome is understandable and does not claim an F9 diagnostics record exists.
3. Import, export, normal reset, and credential deletion clearly describe distinct scopes.

**Current result:** Maintainer confirmed the applicable F4 native scenarios complete on 2026-09-15:
settings persist across relaunch; recovery feedback is understandable and does not claim F9
diagnostics persistence; and import, export, and normal reset present their non-secret scope
clearly. Credential deletion remains a future Secret-owner flow and is not represented as an F4
capability. `./Scripts/verify.sh` also completed on 2026-09-15, including the Debug macOS build
and 65 package tests; it is supporting automated evidence, not a substitute for the confirmation.

## F4 gate

F4 is **complete**: automated rows pass, privacy and retention commitments remain accurate in
`docs/operations/privacy.md`, and the maintainer confirmed the applicable manual scenarios.
