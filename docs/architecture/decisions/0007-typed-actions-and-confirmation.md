# ADR-0007: Use typed action allow-lists and confirmation policies

## Status

Accepted

## Context

Menu, shortcut, IPC, and future AI entry points must produce the same safe operation without becoming an arbitrary execution path.

## Decision

Every executable operation is a registered `ActionID` with validated structured input, availability, authorization, timeout/cancellation behavior, and an explicit confirmation policy. Unknown actions and arbitrary executable paths, scripts, or shell commands are rejected.

## Consequences

All entry points call the Action Registry rather than duplicating business logic. Side-effecting actions have auditable, sanitized outcomes.
