# ADR-0020: Use platform-owned Surface content modes for module-specific composition

## Status

Accepted

## Decision

Xiaozhi contributes a typed, bounded Surface content mode and normalized presentation data; `NotchSurface` owns the SwiftUI renderer and continues to be the sole owner of the one native panel and all Surface transitions. This deliberately avoids both a Xiaozhi-owned panel and raw module views, while permitting the existing home composition to be replaced during an active Xiaozhi session.

## Consequences

The contract must remain protocol-agnostic and prevent high-rate audio, raw WebSocket messages, credentials, and unbounded transcript data from reaching `NotchSurface`. A future module-specific composition is added through the same typed mode boundary rather than importing its Module into the native panel owner.
