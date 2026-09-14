# ADR-0003: Use a root Swift package and static modules before dynamic plugins

## Status

Accepted

## Context

NotchHub needs explicit package boundaries and a simple build, signing, test, and trust model before it can safely host feature modules.

## Decision

Create one root `Package.swift` containing the six platform targets and their tests. `NotchHub.xcodeproj` is the macOS application host that consumes those targets. Modules compile into the app and are registered only at the composition root; dynamic `.dylib` or `.bundle` loading is not supported.

## Consequences

The package graph stays visible to SwiftPM and CI, while Xcode owns app signing, entitlements, and launch configuration. Dynamic loading requires a new ADR covering ABI, signing, sandboxing, distribution, and failure isolation.
