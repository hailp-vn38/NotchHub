# ADR-0014: Always-on Surface and minimal menu bar

## Status

Accepted

## Context

The Notch surface is the primary glanceable interaction surface. User-facing
visibility toggles and a generic long-form Detail Window duplicate lifecycle
and application-scene responsibilities.

## Decision

The menu bar exposes exactly `Settings`, `Restart App Shell`, and `Quit`.

The Notch surface starts automatically in `collapsed` when display geometry is
valid. It has no user-facing enable, disable, or toggle action. `suppressed`,
`recovering`, and `hidden` remain operational states for lifecycle and recovery;
`hidden` is never a user preference.

The generic NotchHub Detail Window and its navigation contract are removed.
Configuration and diagnostics live in dedicated application scenes.

## Consequences

Surface lifecycle is controlled by explicit start/stop operations and display
recovery. Menu-bar actions remain available when the Surface is unavailable,
while diagnostics and development actions are not exposed in `MenuBarExtra`.
