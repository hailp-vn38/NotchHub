# ADR-0013: Admit the fixed expanded surface and own native shaped hit-testing

## Status

Accepted

## Context

The Boring-inspired surface requires a fixed `640 × 190 pt` visual shape in a `640 × 210 pt` native host, while NotchHub must not block unrelated macOS interaction through transparent panel regions. A valid display topology can lack sufficient safe area without indicating a broken panel, and SwiftUI `contentShape` alone cannot make an `NSPanel` click through.

## Decision

`SurfaceCoordinator` treats expanded admission as a topology-versioned capability, not a recovery state: it rejects insufficient safe geometry without scaling/cropping the surface or entering recovery. `NotchPanelController` remains the sole native owner and uses a local/global pointer monitor plus `NSPanel.ignoresMouseEvents` to click through every point outside the visible `NotchSurfaceShape`, except during an explicit native mouse-capture lease. The coordinator owns the authoritative presentation snapshot and interaction-hold session; presentation models only render its projection.

## Consequences

Explicit rejected requests receive bounded accessible feedback and Diagnostics records the event; hover rejection is visually silent. Invalid topology and native apply failures still follow recovery. Geometry/state/capture changes must synchronously recompute native hit-testing, and F2 verification includes click-through, focus/VoiceOver, and admission tests.
