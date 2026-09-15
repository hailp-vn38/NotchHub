# ADR-0015: Versioned settings file and forward-schema recovery

## Status

Accepted

## Context

F4 needs durable typed settings with migrations, atomic recovery, and sanitized import/export.
The prior design permitted either a versioned file or a `UserDefaults` adapter and permitted an
unknown newer schema to fall back to defaults, leaving recovery and import semantics ambiguous.

## Decision

`SettingsBackend` stores one versioned `AppSettings` snapshot in Application Support and atomically
replaces that file after validation. Secrets remain outside this snapshot in Keychain.

F4 import validates the complete Appearance and Notch Behavior snapshot, then atomically replaces
that F4-owned state. It does not merge individual fields or future-phase scopes. A schema newer
than the running app enters read-only recovery: its stored bytes are preserved until the user
updates the app or explicitly confirms reset.

## Consequences

Migration and corruption fixtures exercise one portable serialized artifact, and failed writes or
imports retain the last known-good snapshot. F6, F7, and F9 add shortcut, module, and diagnostics
values only together with their owning behavior and explicit schema migrations.
