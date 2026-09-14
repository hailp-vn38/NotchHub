# ADR-0008: Centralize permission requests in a Permission Coordinator

## Status

Accepted

## Context

Uncoordinated macOS permission prompts damage user trust and make denial, revocation, and testing behavior inconsistent.

## Decision

Modules declare capabilities but never request system permissions directly. The Permission Coordinator owns status refresh, contextual explanation, prompt issuance, and recovery guidance after denial or revocation.

## Consequences

The base app requests no speculative permission at launch. Permission adapters and their failure states are testable without the real system prompt.
