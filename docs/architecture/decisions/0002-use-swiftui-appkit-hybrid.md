# ADR-0002: Use SwiftUI for views and AppKit for native window behavior

## Status

Accepted

## Context

The product needs accessible declarative views as well as exact `NSPanel`, screen, input, and lifecycle control that SwiftUI alone does not own reliably.

## Decision

Use SwiftUI for application scenes, presentation components, and settings views. Use AppKit only behind the `NotchSurface` boundary for native panel, window, screen, and input behavior.

## Consequences

No module or SwiftUI view owns an `NSPanel`; `NotchPanelController` remains its sole owner. AppKit use outside the surface boundary requires an architecture review.
