# ADR-0004: Use the menu bar as the independent recovery surface

## Status

Accepted

## Context

The Notch surface can be hidden, suppressed, misplaced, or temporarily unavailable during macOS lifecycle and display transitions.

## Decision

The menu-bar application shell is independently reachable and owns recovery actions for toggling the surface, opening Settings and Diagnostics, restarting the runtime, and quitting.

## Consequences

No critical control path may exist only inside the Notch surface. F1 lifecycle tests must prove the menu bar remains usable when the panel is unavailable.
