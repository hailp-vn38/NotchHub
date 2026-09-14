# ADR-0005: Use authenticated local IPC before any LAN API

## Status

Accepted

## Context

Future relays and developer tools need an integration boundary, but a network listener would expand the threat model before the foundation is proven.

## Decision

F8 starts with a local Unix domain socket. A loopback HTTP/WebSocket adapter may be added later only when it preserves local-only binding and authentication. No LAN listener is in scope without a separate security design and ADR.

## Consequences

`notchctl` and integrations use the validated local contract. Any interface bound beyond loopback is a new product and security decision.
