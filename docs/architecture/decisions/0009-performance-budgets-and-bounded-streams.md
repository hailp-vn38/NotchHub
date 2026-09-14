# ADR-0009: Enforce performance budgets and bounded streams

## Status

Accepted

## Context

A long-running menu-bar app can silently consume CPU, memory, energy, and responsiveness through streams, logs, timers, and module resources.

## Decision

Every high-rate producer and module declares an update cadence, memory cap, hidden/idle policy, and cleanup owner. Event, log, cache, output, and future transcript buffers are bounded; UI updates are coalesced before presentation.

## Consequences

Diagnostics expose dropped/coalesced data and resource pressure. Performance budgets and stress scenarios are verified at F10, not deferred to a future feature.
