# NotchHub

NotchHub is a single-context, local-first macOS application platform for a calm interaction surface around a MacBook notch. This glossary is the canonical vocabulary for code, ADRs, issues, and module documentation.

## Product and presentation

**App shell**:
The menu-bar-first application host that composes platform dependencies and remains reachable when the Notch surface is unavailable.
_Avoid_: Notch app, panel host

**Notch surface**:
The short-form, native panel presented around the MacBook camera housing or its safe fallback geometry.
_Avoid_: notch window, widget, dashboard

**Surface interaction hold**:
A scoped condition that keeps an expanded Notch surface open while an active user or assistive interaction still requires it.
_Avoid_: hover exception, sticky panel

**Surface interaction session**:
The bounded expanded interaction lifetime to which Surface interaction holds belong; it ends on every authoritative departure from the expanded state.
_Avoid_: panel lifetime, hover session

**Application scene**:
A dedicated application window or scene for configuration, diagnostics, or other content that does not belong in the Notch surface.
_Avoid_: detail state, expanded detail

**Settings shell**:
The application-scene navigation and shared presentation components that expose configuration routes before their typed persistence and capability owners are implemented.
_Avoid_: settings backend, fake preferences

**Setting**:
A validated, non-secret preference with a declared default and reset behavior; it is distinct from session-only presentation state and from a capability that is not yet owned.
_Avoid_: preference key, toggle state

**Settings store**:
The single typed boundary for the current durable settings snapshot, including validation, migration, persistence, reset, and sanitized import/export.
_Avoid_: UserDefaults wrapper, settings UI

**Settings snapshot**:
The complete validated, non-secret configuration state handled as one versioned value by the Settings store.
_Avoid_: preference cache, partial settings write

**Settings recovery outcome**:
A typed result that tells the app whether settings loaded normally, recovered to safe defaults, or require read-only recovery without overwriting a newer snapshot.
_Avoid_: diagnostics record, silent fallback

**Secret**:
A credential or authentication value whose disclosure could grant access or reveal protected data; it is never part of a settings snapshot.
_Avoid_: normal setting, exported configuration

**Module**:
A compile-time feature unit that contributes declared capabilities through NotchHub contracts.
_Avoid_: plugin, extension, widget

**Module runtime**:
The actor that is the sole authority for a Module's registration, lifecycle transition, health projection, and enablement application.
_Avoid_: module manager, module controller

**Module lifetime**:
The scoped ownership boundary supplied to a running Module for tasks, observers, subscriptions, action registrations, and surface contributions; the runtime revokes it on stop or failure.
_Avoid_: cleanup bag, resource tracker

**Module lifetime lease**:
One revocable registration inside a Module lifetime. Revocation runs its supplied cleanup exactly once in reverse registration order; a tracker-only record is not a lease.
_Avoid_: resource name, cleanup hint

**Module enablement intent**:
The durable user choice to enable or disable a Module, stored independently from its transient lifecycle health.
_Avoid_: running state, module health

**Module event publisher**:
The narrow internal capability through which a Module records a declared event during F7; it is not the F8 EventBus, external envelope router, or transport.
_Avoid_: EventBus, IPC event sender

**Module metadata**:
The static, pure declaration of a Module's identity-facing capabilities and resource policy; it is not a mutable runtime-health record.
_Avoid_: module configuration, runtime state

**Runtime restart**:
A composition-level operation that rebuilds the lifetime of all enabled Modules; in F7 it is test-only and distinct from restarting one Module or restarting the App shell.
_Avoid_: Restart App Shell, module restart

**Surface contribution descriptor**:
A typed, bounded description of a Module's content for a declared Surface slot; the platform renders it and retains all surface-transition authority.
_Avoid_: module view, panel content

## Platform contracts

**Action**:
A registered, typed operation identified by an `ActionID` and invoked only through the Action Registry.
_Avoid_: command, arbitrary operation

**Shortcut binding**:
A user-configured keyboard input route to an already registered Action; it neither defines an Action nor owns its execution.
_Avoid_: hotkey command, callback shortcut

**Event envelope**:
A versioned external message wrapper carrying source, type, timestamp, correlation information, and validated payload.
_Avoid_: raw event, untyped message

**Presentation policy**:
The core policy that determines whether a typed event affects the Notch surface and at what intrusiveness.
_Avoid_: module-controlled presentation

**Capability**:
A named platform ability that a module may declare and whose availability can depend on permission or system state.
_Avoid_: direct permission access
