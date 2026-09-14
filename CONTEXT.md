# NotchHub

NotchHub is a single-context, local-first macOS application platform for a calm interaction surface around a MacBook notch. This glossary is the canonical vocabulary for code, ADRs, issues, and module documentation.

## Product and presentation

**Notch surface**:
The short-form, native panel presented around the MacBook camera housing or its safe fallback geometry.
_Avoid_: notch window, widget, dashboard

**Detail view**:
A separately opened, user-requested window or scene for long-form content. It is not a Notch surface state.
_Avoid_: detail state, expanded detail

**Module**:
A compile-time feature unit that contributes declared capabilities through NotchHub contracts.
_Avoid_: plugin, extension, widget

## Platform contracts

**Action**:
A registered, typed operation identified by an `ActionID` and invoked only through the Action Registry.
_Avoid_: command, arbitrary operation

**Event envelope**:
A versioned external message wrapper carrying source, type, timestamp, correlation information, and validated payload.
_Avoid_: raw event, untyped message

**Presentation policy**:
The core policy that determines whether a typed event affects the Notch surface and at what intrusiveness.
_Avoid_: module-controlled presentation

**Capability**:
A named platform ability that a module may declare and whose availability can depend on permission or system state.
_Avoid_: direct permission access
