# Local IPC
## NotchHub — Unix Socket, Loopback HTTP/WebSocket, Authentication, and Routing

**Status:** Draft v0.1  
**Owner:** Architecture / Security  
**Last updated:** 2026-09-13  
**Related documents:** [Architecture Overview](overview.md), [C4 Container](c4-container.md), [Event Protocol](event-protocol.md), [Action Platform](action-platform.md), [State Management](state-management.md), [Threat Model](../security/threat-model.md), [Requirements §5.8](../product/requirements.md#58-local-ipc)

---

## 1. Purpose

NotchHub provides a local integration boundary so that `notchctl`, local automation, tests, and future adapters—such as a Xiaozhi relay—can send validated events or invoke registered actions without importing the app's internal Swift packages.

The IPC design is **local-first and deny-by-default**:

- Prefer a Unix domain socket for same-user local tooling.
- Use loopback-only HTTP/WebSocket when a language-neutral or streaming interface is needed.
- Authenticate requests where the selected transport requires it.
- Validate every envelope/action before it reaches `EventBus` or `ActionRegistry`.
- Rate-limit, size-limit, and diagnose invalid requests.
- Never accept arbitrary shell commands, executable paths, or executor configuration.
- Never expose a LAN device-control, IoT, MQTT, BLE gateway, or hardware-control interface.

---

## 2. IPC goals and non-goals

### Goals

1. Give local scripts/tools a stable public contract.
2. Keep the app's Swift package internals private from companion tools.
3. Support health/status queries, test event injection, and registered actions.
4. Support future streaming events without moving protocol parsing into Notch UI.
5. Provide authentication, request validation, source allow-lists, rate limiting, and audit records.
6. Make IPC testable with fixtures and an in-memory transport.
7. Keep the default attack surface local to the user's own Mac.

### Non-goals

- No LAN-accessible server in the foundation.
- No cloud relay or public internet endpoint.
- No remote administration or multi-user access model.
- No arbitrary script/shell execution endpoint.
- No ESP32/IoT/LAN device-control or hardware command route.
- No direct UI/window manipulation endpoint.
- No endpoint that accepts raw Xiaozhi protocol; a future relay must normalize it first.

---

## 3. Transport decision

### 3.1 Recommended order

```text
Phase F8, first: Unix domain socket
Phase F8/Future: loopback HTTP for simple language-neutral clients
Phase F8/Future: loopback WebSocket for streaming adapters when needed
```

### 3.2 Transport comparison

| Transport | Strength | Weakness | Recommendation |
|---|---|---|---|
| Unix domain socket | Local-only, efficient, good same-user boundary, no TCP port | Less convenient from some tools/languages; needs framing | Preferred for `notchctl` and local scripts |
| Loopback HTTP | Easy to inspect/use from Python, Node, shell, and tests | Requires token/auth and port management | Add for simple request/response integrations |
| Loopback WebSocket | Full-duplex stream for future assistant/status relay | More lifecycle/reconnect complexity | Add only when a concrete stream consumer exists |
| LAN HTTP/WS | Remote access | Larger attack surface, authentication/TLS complexity, conflicts with product scope | Not supported in current product |

### 3.3 Default binding

- Unix socket path under a user-specific runtime/application support location with restrictive permissions.
- If HTTP/WebSocket is enabled, bind only to `127.0.0.1`.
- Never bind to `0.0.0.0`, wildcard IPv6, or a LAN interface by default.
- The bound address and transport state must be shown in Diagnostics.

---

## 4. IPC architecture

```mermaid
flowchart LR
    CLI[notchctl / local script]
    Relay[Future Xiaozhi relay]
    Transport[Unix socket / loopback HTTP/WS]
    Auth[RequestAuthenticator]
    Limits[Size + rate limits]
    Decode[Decoder]
    Router[IPCRouter]
    Events[EventRouter → EventBus]
    Actions[ActionRegistry]
    Health[Health/Status provider]
    Diagnostics[Sanitized Diagnostics]

    CLI --> Transport
    Relay --> Transport
    Transport --> Auth
    Auth --> Limits
    Limits --> Decode
    Decode --> Router
    Router --> Events
    Router --> Actions
    Router --> Health
    Auth --> Diagnostics
    Limits --> Diagnostics
    Router --> Diagnostics
```

### Components

| Component | Responsibility |
|---|---|
| `IPCServer` | Owns listener lifecycle and accepted client sessions |
| `RequestAuthenticator` | Validates transport/client credentials and source identity |
| `RequestRateLimiter` | Tracks per-client/source/type rate and rejects or coalesces excess requests |
| `PayloadValidator` | Enforces message size, JSON/decode, schema, version, and field constraints |
| `IPCRouter` | Dispatches validated requests to health, event, or action route |
| `EventRouter` | Converts event requests to typed `AppEvent` and publishes to EventBus |
| `ActionRoute` | Converts action request to typed `ActionInvocation` and calls ActionRegistry |
| `HealthRoute` | Returns sanitized app/runtime/surface/IPC status |
| `DiagnosticsReporter` | Records intake outcomes, rejection reason, latency, and bounded client metrics |

No component in this chain directly calls an `NSPanel` or SwiftUI view.

---

## 5. Authentication and client identity

### 5.1 Unix socket policy

Unix socket access is local, but local processes should still be treated as conditionally trusted:

- Create socket with restrictive user permissions.
- Place it in a per-user runtime/application directory, not a world-writable shared directory.
- Remove stale socket safely during startup after verifying ownership/identity where practical.
- Validate peer credentials where the platform API supports it.
- Use an application-level source identity/nonce for `notchctl` or clients that need stronger attribution.
- Record accepted/rejected client metadata without storing sensitive command payloads.

### 5.2 HTTP/WebSocket policy

If loopback HTTP/WebSocket is enabled:

- Generate a random token during first secure initialization.
- Store the token in Keychain or a protected local credential store.
- Require an authorization header for HTTP:

```http
Authorization: Bearer <token>
```

- Require authentication during WebSocket handshake before accepting event/action messages.
- Never print the token in logs, diagnostics, shell output, or error responses.
- Rotate/revoke token through Settings → Security/IPC or a documented reset action.
- Use constant-time token comparison where applicable.

Example WebSocket handshake metadata:

```json
{
  "type": "client.hello",
  "version": 1,
  "clientID": "xiaozhi-relay",
  "capabilities": ["assistant.events"],
  "nonce": "server-provided-or-client-generated-nonce"
}
```

The server must map `clientID` to an allow-list. A valid token alone does not allow every event family or action.

### 5.3 Client source allow-list

| Client/source | Allowed operations |
|---|---|
| `notchctl` | Health/status; development test events; foundation actions explicitly enabled |
| `demo.injector` | Development-only DemoModule/test events |
| `xiaozhi.relay` (future) | `assistant.*` events and explicitly approved assistant actions |
| Unknown client | Health may be limited; no event/action access |

The allow-list is application policy, not client self-declaration. A client cannot claim a privileged identity just by sending a string.

---

## 6. Message framing and request envelope

### 6.1 Request envelope

```json
{
  "requestID": "7c08f5d4-5c46-4be0-9549-a875c37e1ed3",
  "protocolVersion": 1,
  "clientID": "notchctl",
  "operation": "event",
  "body": {}
}
```

| Field | Type | Required | Rule |
|---|---|---:|---|
| `requestID` | UUID string | Yes | Used for tracing/idempotent response correlation |
| `protocolVersion` | Positive integer | Yes | Unsupported versions fail closed |
| `clientID` | Registered string | Yes | Checked against authenticated client/source policy |
| `operation` | `health`, `status`, `event`, `action`, `stream` | Yes | Route allow-list |
| `body` | JSON value | Depends | Validated by operation schema |

For line/socket transports, use explicit message framing and maximum frame length. Do not read until EOF for a request that may keep the connection open.

### 6.2 Event body

```json
{
  "event": {
    "id": "f3c61e35-245a-4c7d-8f9f-a967a1e52bd4",
    "version": 1,
    "source": "demo.injector",
    "type": "demo.status.changed",
    "timestamp": "2026-09-13T01:00:00Z",
    "correlationID": null,
    "sequence": 1,
    "priority": "normal",
    "payload": {
      "title": "Foundation test",
      "message": "IPC is working"
    }
  }
}
```

The event is validated by `EventRouter` according to [`event-protocol.md`](event-protocol.md), not trusted merely because it arrived over an authenticated channel.

### 6.3 Action body

```json
{
  "actionID": "app.openSettings",
  "input": {}
}
```

Forbidden:

```json
{
  "command": "arbitrary shell text"
}
```

No IPC request can define a new Action ID, executor kind, executable path, script, shell string, LAN target, hardware target, or timeout outside registered action policy.

---

## 7. Response model

### 7.1 Success response

```json
{
  "requestID": "7c08f5d4-5c46-4be0-9549-a875c37e1ed3",
  "protocolVersion": 1,
  "ok": true,
  "body": {
    "accepted": true
  }
}
```

### 7.2 Error response

```json
{
  "requestID": "7c08f5d4-5c46-4be0-9549-a875c37e1ed3",
  "protocolVersion": 1,
  "ok": false,
  "error": {
    "code": "ipc.action_not_allowed",
    "message": "This client is not allowed to invoke the requested action."
  }
}
```

Error messages must be safe for clients and must not include stack traces, tokens, internal file paths, raw payloads, or secret data.

### 7.3 Error codes

```text
ipc.invalid_frame
ipc.unsupported_protocol_version
ipc.authentication_required
ipc.authentication_failed
ipc.client_not_allowed
ipc.request_too_large
ipc.rate_limited
ipc.invalid_json
ipc.invalid_request
ipc.unknown_operation
ipc.invalid_event
ipc.event_not_allowed
ipc.unknown_action
ipc.action_not_allowed
ipc.action_invalid_input
ipc.server_unavailable
ipc.internal_error
```

---

## 8. Routes

### 8.1 Health

```text
GET /v1/health
```

Returns minimal process/service status, for example:

```json
{
  "ok": true,
  "protocolVersion": 1,
  "app": {
    "version": "0.1.0",
    "build": "100",
    "uptimeSeconds": 1234
  },
  "ipc": {
    "transport": "unixSocket",
    "ready": true
  }
}
```

Health output must not include secrets, full settings, personal data, or raw event history.

### 8.2 Status

```text
GET /v1/status
```

Returns a sanitized snapshot:

- Surface state.
- Runtime/module health summary.
- Permission status summary.
- IPC counters.
- Recent error count.
- Performance/resource summary where enabled.

### 8.3 Events

```text
POST /v1/events
```

- Requires client/source allow-list.
- Requires valid `EventEnvelope`.
- Returns accepted/rejected result and `requestID`.
- Asynchronous module/presentation results are delivered through event stream or diagnostics, not by blocking the request indefinitely.

### 8.4 Actions

```text
POST /v1/actions/{actionID}
```

- Requires source authorization.
- Input is validated against registered action schema.
- Confirmation-required actions must surface a user confirmation flow; the request returns a pending/confirmation-required result rather than bypassing user approval.
- Results are correlated by `requestID` and `ActionInvocationID`.

### 8.5 Stream

```text
WS /v1/stream
```

Optional until a real streaming integration requires it. If implemented:

- Authenticate at handshake.
- Send a bounded server hello/status response.
- Apply per-client event subscription allow-list.
- Do not stream all diagnostics/raw events by default.
- Apply backpressure/queue limits and disconnect clients that do not consume data.
- Do not send raw audio, authorization headers, full clipboard/file/calendar payloads, or unrestricted event history.

---

## 9. Validation and limits

### 9.1 Request validation

Reject requests when:

- Frame/body exceeds configured limit.
- JSON is malformed or nesting is too deep.
- Protocol version is unsupported.
- Authentication/client identity is invalid.
- Operation is unknown or not allowed for the client.
- Event/action schema is invalid.
- Action is unknown/unavailable or input fails validation.
- Timestamp/sequence policy fails for an event.

### 9.2 Initial limits

Exact values are implementation choices but must be explicit and tested:

| Limit | Initial target |
|---|---:|
| Maximum request/frame | 256 KB default |
| Maximum event payload | 256 KB or lower per event type |
| Maximum string field | Event/action schema-specific |
| Maximum nested JSON depth | 16–32 levels |
| Per-client request rate | Configured by operation/source |
| Event stream queue | Bounded count and byte limit |
| Response size | Bounded; use async event/result for large output |
| Authentication failure burst | Small threshold then temporary backoff |

### 9.3 Rate limiting

Maintain buckets by:

```text
clientID + operation
clientID + event type
clientID + actionID
```

Recommended behavior:

- Health/status requests: moderate burst, low cost.
- Test/status events: bounded.
- High-rate stream events: strict per-type limits and coalescing.
- Actions: stricter limit to prevent repeated side effects.
- Authentication failures: backoff and diagnostic counter.

Rate-limit state is bounded and must not become an unbounded client map.

---

## 10. IPC lifecycle

### 10.1 Startup

```text
AppCoordinator starts
        ↓
Load secure IPC credential/policy
        ↓
Remove/validate stale Unix socket if applicable
        ↓
Create listener with restrictive permissions
        ↓
Start accept loop
        ↓
Publish ipc.ready
```

IPC should start only after core stores, Action Registry, EventRouter, and Diagnostics are ready. This prevents requests from reaching a partially initialized application.

### 10.2 Shutdown

```text
Stop accepting new clients
        ↓
Send/allow bounded graceful close
        ↓
Cancel active stream tasks
        ↓
Cancel/finish safe request tasks
        ↓
Remove socket safely
        ↓
Publish ipc.stopped
```

A hung or malicious client must not block app shutdown indefinitely.

### 10.3 Reconnect

Clients should use bounded exponential backoff. The server does not create a tight reconnect loop on behalf of clients.

For future Xiaozhi relay:

- Relay connection retry is owned by the relay/adapter, not Notch UI.
- NotchHub receives normalized connection state events.
- Duplicate/replayed events are handled according to event ID/sequence policy.

---

## 11. `notchctl` CLI

### 11.1 Purpose

`notchctl` is a small separate executable used to inspect and exercise the public local IPC contract.

### 11.2 Planned commands

```bash
notchctl health
notchctl status
notchctl emit surface.compact --title "Foundation test" --message "IPC is working"
notchctl emit demo.status.changed --json payload.json
notchctl action app.openSettings
notchctl action surface.toggleDebugOverlay
notchctl modules
```

### 11.3 CLI security

- Read token from Keychain or a user-approved secure configuration path; do not pass secrets in shell history where avoidable.
- Never expose raw token with normal `--verbose` output.
- Use the same schema validator/fixture contract as other clients.
- Do not add an `exec`, `shell`, `script`, `lan`, `device`, `mqtt`, `ble`, or hardware-control command.

---

## 12. Error handling and diagnostics

Every rejected request should produce:

- Safe client error code/message.
- Request ID.
- Sanitized diagnostics record with source/client, operation, reason code, timestamp, and latency.
- Bounded rejection counter.

Do not store:

- Bearer tokens.
- Authorization headers.
- Full raw request bodies for sensitive requests.
- Arbitrary external payloads without redaction.
- Internal stack traces in client responses.

Diagnostics should show:

```text
IPC transport and bind mode
Listener ready/not ready
Active client count (bounded/aggregated)
Accepted/rejected request counts
Rate-limit count
Authentication failure count
Event/action route latency
Active stream count
Queue/buffer utilization
Last server error
```

---

## 13. Security threat scenarios

| Scenario | Required control |
|---|---|
| Another local process sends a fake event | Auth/source allow-list, schema validation, diagnostics |
| Client floods events | Per-client/type rate limit, bounded queues, coalescing, disconnect/backoff |
| Client sends oversized/nested payload | Frame/body/depth limits and early rejection |
| Client invokes unknown action | Registry lookup and source policy rejection |
| Client sends raw shell/executor config | Schema has no such field; reject/ignore unknown or prohibited fields |
| Token appears in logs | Redaction policy and logger review tests |
| Stale socket is hijacked | Restrictive path/permissions, ownership check, safe stale-socket handling |
| Client never consumes WebSocket data | Bounded queue, backpressure, disconnect policy |
| App shuts down with malicious client | Bounded graceful shutdown and cancellation |
| Future relay forwards raw protocol dump | Adapter schema only accepts normalized events; payload limits |

---

## 14. Testing requirements

### Unit tests

- Request envelope encode/decode.
- Authentication success/failure.
- Client/source allow-list.
- Protocol version compatibility.
- Invalid JSON/frame/nesting/size.
- Event schema and source/type policy.
- Action schema and source authorization.
- Rate-limit buckets and expiry.
- WebSocket subscription allow-list if enabled.
- Response/error redaction.
- Stale socket path handling.

### Integration tests

```text
notchctl/fixture client
        → transport
        → auth
        → IPC router
        → EventRouter/ActionRegistry
        → EventBus/action result
        → diagnostics
```

Verify:

- Valid event reaches the intended module/store.
- Invalid event never reaches EventBus subscribers.
- Valid foundation action reaches the executor.
- Unknown/raw-command action is rejected.
- User confirmation is not bypassed through IPC.
- Event flood keeps app responsive and records coalesced/dropped counters.
- Shutdown completes with clients connected.
- Reconnect and duplicate request behavior is bounded/idempotent as specified.

### Manual tests

- Start app with no socket, stale socket, and expected socket.
- Run CLI before/after app startup.
- Invalid token and revoked token.
- Multiple clients.
- Payload flood.
- WebSocket client disconnect/reconnect if implemented.
- App sleep/wake and lock/unlock with client connected.
- Diagnostics export after rejected requests confirms redaction.

---

## 15. Versioning and compatibility

- `protocolVersion: 1` is the initial IPC contract.
- Additive optional fields may be ignored safely.
- Changes to authentication, operation semantics, required fields, or security behavior require a new protocol version or ADR-defined compatibility layer.
- Unknown protocol versions fail closed.
- Endpoint versioning uses `/v1/...`; incompatible API changes use `/v2/...` or a documented migration layer.
- Maintain fixture tests for supported versions.

---

## 16. Privacy and data handling

- IPC is local by default, but local does not mean automatically trusted.
- Do not expose full settings, transcript, clipboard, file, calendar, or diagnostics data through `status` unless explicitly requested and permissioned.
- Sensitive event bodies are not copied into generic diagnostics.
- Future Xiaozhi transcript content is user-content-sensitive and must have explicit retention settings.
- No external IPC request can create a LAN/device-control path.

---

## 17. Explicit scope boundary

The IPC platform is for NotchHub's macOS desktop integrations and future assistant relay. It must not be extended to:

- ESP-IDF build/flash/monitor commands.
- ESP32 gateway or BLE device telemetry.
- IoT/MQTT/smart-home control.
- LAN device control or hardware command routing.

These are permanent product exclusions. A future separate product may define another IPC protocol, but NotchHub's local IPC contract must remain focused and narrow.

---

## 18. Summary

NotchHub's IPC is a local, authenticated, validated, bounded boundary—not a general remote-control server. It gives `notchctl`, local automation, and a future Xiaozhi relay a stable way to publish normalized events and invoke explicitly registered actions while keeping the core app, panel, permissions, and security model protected.

The transport can evolve from Unix socket to loopback HTTP/WebSocket as real use cases require, but the core guarantees remain: local-only by default, source allow-list, typed event/action contracts, no arbitrary execution, bounded resources, observable failures, and no hardware/LAN-control scope.
