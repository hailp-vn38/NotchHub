# ADR-0010: Support the built-in display first

## Status

Accepted

## Context

Reliable multi-display and notch geometry behavior has a disproportionate lifecycle and QA cost for the foundation.

## Decision

The first supported presentation target is the built-in MacBook display, with a safe top-center fallback when physical notch geometry is unavailable. Full multi-display placement parity is deferred.

## Consequences

F2/F10 must test attach, detach, scale, Space, and full-screen recovery without claiming a multi-display feature that has not been validated.
