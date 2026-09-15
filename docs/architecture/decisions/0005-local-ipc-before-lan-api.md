# ADR-0005: Use authenticated loopback HTTP before any LAN API

## Status

Accepted

## Context

Future relays and developer tools need an integration boundary, but a network listener would expand the threat model before the foundation is proven. A Unix socket would make the first boundary less inspectable and less convenient for the developer CLI and cross-language local clients. A WebSocket would add connection, reconnection, and slow-consumer lifecycle before F8 has a real streaming consumer.

## Decision

F8 starts with authenticated HTTP bound exclusively to `127.0.0.1`. Every route requires a non-hardcoded token stored in Keychain, and event/action requests additionally require a fixed server-side IPC-source allow-list. F8 provides no Unix socket and no WebSocket stream. A Unix socket or WebSocket may be proposed later only for a concrete consumer and with a transport-specific lifecycle, authentication, and backpressure design. No LAN listener is in scope without a separate security design and ADR.

## Consequences

`notchctl` and integrations use one inspectable HTTP contract. Loopback does not make a client trusted: token authentication, source policy, validation, limits, and Action Registry policy remain mandatory. Any LAN-facing interface is a new product and security decision.
