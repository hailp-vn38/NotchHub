# ADR-0011: Use public macOS APIs first

## Status

Accepted

## Context

Private frameworks and privileged helpers create compatibility, signing, distribution, and user-trust risks that are not justified in the foundation.

## Decision

Use documented public macOS APIs first. A privileged helper, entitlement-sensitive capability, or private API is excluded unless a later ADR records the user value, alternatives, security model, distribution impact, and test plan.

## Consequences

Potential capabilities may remain unavailable rather than bypass platform policy. Any approved helper must be isolated from core platform contracts.
