# ADR-0007: Use typed action allow-lists and confirmation policies

## Status

Accepted

## Context

Menu, shortcut, IPC, and future AI entry points must produce the same safe operation without becoming an arbitrary execution path.

## Decision

Every executable operation is a registered `ActionID` with validated structured input, availability, authorization, timeout/cancellation behavior, and an explicit confirmation policy. Unknown actions and arbitrary executable paths, scripts, or shell commands are rejected.

A Shortcut binding is only a persisted, user-configured input route to a registered Action. F6
introduces no default binding or shortcut-specific Action; it supports app-active recognition only.
Bindings for Actions not registered in the current app state are retained as unavailable and never
dispatched. Conflicts reject the new binding rather than replacing an existing one.

## Consequences

All entry points call the Action Registry rather than duplicating business logic. Side-effecting actions have auditable, sanitized outcomes.

Global shortcut support remains a later explicit API and Accessibility decision; it cannot be
inferred from the existence of a Shortcut binding.
