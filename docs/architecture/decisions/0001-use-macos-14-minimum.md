# ADR-0001: Support macOS 14 as the minimum deployment target

## Status

Accepted

## Context

NotchHub needs modern SwiftUI, Observation, concurrency, and AppKit APIs while remaining practical to test and distribute.

## Decision

Set the application deployment target to macOS 14 Sonoma. Build hosts and CI must use the Xcode version pinned by the F0 scaffold; the deployment target remains independent of the build-host macOS version.

## Consequences

The codebase may use macOS 14 APIs directly where documented, but any later increase in the minimum version requires a replacement ADR and requirement update.
