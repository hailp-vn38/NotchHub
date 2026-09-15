# ADR-0016: Supervised Module lifecycle and bounded shutdown

## Status

Accepted

## Context

F7 introduces statically linked Modules that may start asynchronously, fail, or
be disabled while starting. The platform must isolate those failures without
allowing concurrent UI requests to race lifecycle state, retain resources, or
block application termination indefinitely.

## Decision

`ModuleRuntime` is an actor and the only authority that changes a Module's
lifecycle. It serializes commands per Module. Disabling during `starting`
cancels startup, invokes `stop()` exactly once, and finishes in `stopped`.
A manual restart is valid from `running`, `suspended`, or `failed`, and always
uses `stop → starting`.

F7 performs no automatic retry. A failure remains `failed` until a user starts
it again or restarts the runtime.

The runtime supplies a Module lifetime scope and revokes all registered owned
resources on stop or failure. `start` has a five-second limit, `stop` a
two-second limit, and complete runtime shutdown a five-second limit. A timeout
cancels known work, reports a failed timeout outcome, and does not block the
App shell from terminating.

Module lifecycle work is cooperatively cancellable: a Module must observe
task cancellation and return from `start` or `stop` after the runtime revokes
its lifetime. Swift cannot safely force-stop arbitrary async work. A Module
that does not cooperate is failed and loses all platform leases; it is never
allowed to retain platform registrations while the App shell continues.

Enablement is a durable user intent, separate from transient Module health.
F7 migrates settings to schema v3 and enables `demo` by default.

## Consequences

Module authors use the supplied Module lifetime instead of retaining platform
registrations independently. Runtime health can distinguish an enabled Module
that failed from a Module the user explicitly disabled. A stuck Module can
leave incomplete cleanup, but cannot make the host wait indefinitely; its
timeout is observable and covered by tests.
