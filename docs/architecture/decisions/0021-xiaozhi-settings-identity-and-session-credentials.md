# ADR-0021: Persist Xiaozhi identity in Module settings and keep credentials session-only

## Status

Accepted

## Context

Xiaozhi Settings must let a user inspect, edit, generate, clear, revert, and apply its Device ID and Client ID. The earlier direct-client decision placed both identity and credentials in Keychain, which prevents the requested draft-and-apply workflow and makes identity opaque to the Module settings schema.

## Decision

`XiaozhiSettings` owns the non-secret Bootstrap URL, Device ID, and Client ID as validated, versioned Module settings. They are persisted only after Apply and participate in the ordinary settings migration and sanitized export/import flow. Xiaozhi does not use Keychain.

A bootstrap WebSocket token is a Session credential: it is kept only in memory for one active voice session or explicit connection test. Every new session, restart, and connection test performs bootstrap again. Tokens, activation codes, and raw transport values remain absent from settings, export, diagnostics, and presentation.

## Consequences

Settings schema v7 migrates earlier Xiaozhi entries by generating valid identity defaults. A connection test can exercise bootstrap, handshake, one microphone-free silence conversation, TTS, Opus, and playback drain without changing the active Module runtime or Notch surface.
