# ADR-0017: Place lifecycle contracts in NotchCore

## Status

Accepted

## Context

The pure `NotchDomain` package cannot depend on Core capability handles, while
the executable lifecycle protocol needs a context containing those handles.
Putting both sides in Domain would either create a dependency cycle or make the
pure domain package expose platform-runtime details. Core also must not own
concrete demo feature behavior.

## Decision

`NotchDomain` owns only pure Module identifiers, metadata, lifecycle states,
and health DTOs. `NotchCore` owns `NotchModule`, `ModuleContext`,
`ModuleLifetime`, `ModuleRuntime`, and `ModuleEventPublisher`.

`NotchDemoModule` is a separate static Swift package target depending on Core
and Domain. The composition root is its sole registration point. It is
registered only in Debug/test builds; release builds do not expose it.

## Consequences

The package graph remains acyclic and Core retains no concrete feature logic.
Module authors depend on an explicit runtime contract. The app composition root
must select build-configuration-appropriate module registration, and automated
plus native Debug evidence is required for the demo path.
