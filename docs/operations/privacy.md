# Privacy and Data Retention
## NotchHub — User-facing data commitments

**Status:** Draft v0.1
**Owner:** Operations / Security
**Last updated:** 2026-09-15
**Location:** `docs/operations/privacy.md`
**Related documents:** [Data Persistence](../architecture/data-persistence.md), [Threat Model](../security/threat-model.md), [Requirements §8](../product/requirements.md#8-data-requirements), [Settings UI specification](../design/notchhub-settings-ui-spec.md)

---

## 1. Purpose

This document states the privacy and retention commitments that apply to NotchHub. It is the
user-facing policy; the storage contracts and implementation detail live in
[Data Persistence](../architecture/data-persistence.md).

## 2. Data commitments

- Ordinary F4 settings contain only non-secret Appearance and Notch Behavior preferences.
- The ordinary-settings snapshot is a versioned file in Application Support. NotchHub atomically
  replaces it only after validation; an unrecognized newer version is preserved, not replaced by
  defaults.
- Credentials, authentication tokens, and IPC secrets are not settings. They use Keychain or an
  equivalent secure store and are excluded from normal reset, import, export, and diagnostics.
- NotchHub does not retain transcript, clipboard, file, calendar, screen, camera, or audio
  content by default. A future module may retain such content only after an explicit opt-in,
  a documented retention limit, and a module privacy review.
- Diagnostics contain bounded, sanitized summaries such as error codes, timestamps, and counters;
  they do not contain secrets or raw user content by default.
- Rebuildable caches are bounded and have an explicit clear or expiry policy before they are
  introduced.

## 3. User controls

- Normal settings reset removes non-secret configuration only and explains its scope before
  confirmation.
- Credential deletion is a separate destructive action. It is never bundled into normal reset.
- Export contains a sanitized settings snapshot and excludes secrets, raw user-content histories,
  raw payloads, and sensitive paths.
- Import validates the complete F4-owned snapshot before atomically replacing it. A failed import
  retains the last known good configuration and records only a sanitized outcome.
- A future module that persists user content must provide a clear deletion path and state whether
  deletion is immediate, delayed by bounded cache cleanup, or requires restart.

## 4. Retention and future capabilities

F4 establishes the persistence boundary but does not introduce retained user content. Shortcut
configuration, module data, and diagnostics policy are introduced only by their F6, F7, and F9
owners. Their user-facing retention commitments must be added here before they can persist data.

Corrupt ordinary-settings snapshots may be retained only in a bounded local quarantine so recovery
does not silently overwrite them. Quarantine is excluded from import/export and is never an active
configuration source. It retains at most three files of at most 1 MiB each (3 MiB total), deleting
the oldest file before admitting another snapshot.

## 5. Verification commitments

Privacy-related changes require tests that confirm secrets are excluded from settings, exports,
diagnostics, fixtures, and logs; corrupted or invalid imports recover safely; and each retained
data class remains within its documented limit.

On 2026-09-15, the F4 Settings store tests confirmed that an export has only the versioned
Appearance and Notch Behavior snapshot, imports carrying an extra credential or future-phase field
are rejected without replacement, and normal reset writes safe F4 defaults only. Native macOS
privacy UX still requires the manual scenarios recorded in [F4 evidence](../quality/f4-evidence.md).
