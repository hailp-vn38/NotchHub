# Module authoring

## Purpose

This guide defines the smallest complete proposal for a static NotchHub Module.
It is a contract checklist, not a recipe for copying `DemoModule` implementation
details.

## Before implementation

1. Copy [`docs/modules/_template.md`](../modules/_template.md) into a named
   module document and complete every section.
2. Choose a valid, stable `ModuleID`; do not reuse another module's namespace.
3. Declare only the metadata required by the module contract: display name,
   version, slots, capabilities, and runtime policy.
4. State which settings are durable Module enablement intent and which are
   module-owned schema values. Secrets are separate from settings.
5. Name actions and events before code. Actions are typed and registered through
   the platform; events do not force a surface transition.
6. Define the Module lifetime ownership of every task, observer, subscription,
   action registration, surface contribution, socket, and cache.

## Implementation rules

- Put concrete feature code in its own static package target; do not add it to
  `NotchCore`.
- Depend on `NotchCore` and `NotchDomain`; never create a reverse dependency
  from Domain to Core.
- Use `ModuleContext` capability handles only. Never manipulate `NSPanel`,
  request privacy permission directly, read another Module's settings, or add
  an IPC listener.
- Register only descriptors for declared slots. The platform retains layout and
  surface-transition policy.
- Register every owned resource with the Module lifetime and make `stop()` safe
  during startup or failure.
- Treat failure as isolated: propagate typed errors to the runtime, not fatal
  errors or detached work.

## Validation before merge

- Unit tests cover metadata validation, start/stop, failure, explicit restart,
  settings isolation, actions, events, and lifetime cleanup.
- Integration tests prove enable/disable leaves no registered resource and does
  not affect another Module.
- Include a repeated enable/disable test appropriate to the declared resource
  policy; F7 uses 100 iterations for DemoModule.
- Run relevant native macOS QA whenever the Module renders a surface descriptor
  or depends on platform capability behavior.
- Update the module document, tests, relevant architecture/security/performance
  docs, and an ADR only for a durable cross-cutting decision.
