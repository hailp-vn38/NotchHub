# F6 Shortcut Framework

**Status:** ready-for-human
**Phase:** F6

## Scope

Provide the typed, persisted shortcut-binding framework without registering a concrete Action,
shortcut default, global hotkey, or Accessibility permission request.

## Acceptance criteria

- `ShortcutBinding` targets an existing `ActionID`; it does not contain a callback or executor.
- The binding store persists through `SettingsStore` schema v2 and migrates F4 v1 snapshots with
  an empty binding list.
- A duplicate key/modifier combination is rejected without replacing its existing binding.
- A binding for an Action that is not registered remains visible as unavailable and can be cleared.
- Settings → Shortcuts renders an explicit empty state when no Action is available.
- Shortcut handling is app-active only. Global registration and Accessibility remain out of scope.

## Out of scope

Concrete Action registration or execution, key-event capture, global hotkeys, confirmation,
IPC, module Actions, and any Accessibility prompt.
