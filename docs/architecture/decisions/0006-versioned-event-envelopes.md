# ADR-0006: Use versioned event envelopes for external input

## Status

Accepted

## Context

External relays and tools evolve independently, while the core and surface must not consume malformed or protocol-specific data.

## Decision

All external input crosses the boundary as a versioned `EventEnvelope` with an ID, version, source, type, timestamp, optional correlation ID, and validated payload. It is decoded and validated before becoming a typed internal event.

## Consequences

Raw protocol payloads never reach `NotchSurface`. Schema evolution, size limits, rejection counters, and fixtures are mandatory parts of the event contract.
