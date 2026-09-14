# ADR-0012: Keep contracts and decisions as reviewed documentation in Git

## Status

Accepted

## Context

The foundation spans product scope, package boundaries, security, performance, and macOS lifecycle behavior that cannot be inferred safely from implementation alone.

## Decision

Documentation, ADRs, and the root `CONTEXT.md` are versioned with the code. Behavioural or durable architecture changes update their authoritative documents in the same pull request. The F0 scaffold pins its Xcode/Swift toolchain and declares one formatter; lint rules remain optional until a small checked-in rule set is adopted.

## Consequences

Documentation links and required files are CI checks. `CONTEXT.md` is the canonical vocabulary; product requirements may repeat terms for reader clarity but must not redefine them.
