# Native Xiaozhi Client
## Xiaozhi connection, session, audio and protocol specification for NotchHub

**Status:** Architecture / implementation specification  
**Target platform:** macOS 14+  
**Target module:** Native Xiaozhi Client  
**Primary upstream reference:** `78/xiaozhi-esp32`  
**Preferred transport:** WebSocket  
**Initial audio mode:** microphone input + TTS playback  
**NotchHub role:** Xiaozhi device/client, not observer/relay

---

## 1. Purpose

This document defines how NotchHub should connect directly to the Xiaozhi backend and behave as a native Xiaozhi client on macOS.

The goal is:

```text
Mac microphone
      │
      ▼
 NotchHub
 Native Xiaozhi Client
      │
      │ HTTPS bootstrap
      │ WSS JSON + Opus
      ▼
 Xiaozhi Backend
      │
      ▼
 STT / LLM / TTS / MCP
      │
      ▼
 NotchHub audio + Notch UI
```

NotchHub is therefore a Xiaozhi endpoint in its own right.

It is **not**:

```text
ESP32 -> Xiaozhi -> relay -> NotchHub
```

and it does not attempt to observe another Xiaozhi device's active session.

---

# 2. Upstream source of truth

Implementation must be cross-checked against the current upstream code rather than relying only on examples in this document.

Primary source files:

```text
78/xiaozhi-esp32/

main/
├── application.cc
├── ota.cc
├── ota.h
├── device_state.h
├── protocols/
│   ├── protocol.h
│   ├── protocol.cc
│   ├── websocket_protocol.h
│   ├── websocket_protocol.cc
│   └── mqtt_protocol.*
├── audio/
│   ├── audio_service.h
│   └── audio_service.cc
├── boards/common/
│   ├── board.h
│   └── board.cc
└── mcp_server.*

docs/
├── websocket.md
├── mqtt-udp.md
├── mcp-protocol.md
└── mcp-usage.md
```

The upstream repository is MIT licensed. If code is copied or substantially adapted rather than independently reimplemented, the MIT copyright and permission notice must be retained as required by that license.

---

# 3. Architecture decision

The first Native Xiaozhi Client implementation SHALL use WebSocket.

The MQTT + UDP transport is explicitly out of initial scope.

Reason:

```text
WebSocket
 ├── control JSON
 └── binary Opus
```

versus:

```text
MQTT
 └── control JSON

UDP
 └── AES-CTR encrypted Opus
```

WebSocket gives NotchHub one session transport and maps naturally to macOS networking.

A future transport abstraction may support MQTT + UDP without changing the Xiaozhi session layer.

Recommended abstraction:

```swift
protocol XiaozhiTransport: Sendable {
    var events: AsyncStream<XiaozhiTransportEvent> { get }

    func connect(configuration: XiaozhiConnectionConfiguration) async throws
    func send(text: Data) async throws
    func send(binary: Data) async throws
    func disconnect() async
}
```

Initial implementation:

```text
XiaozhiTransport
       │
       └── XiaozhiWebSocketTransport
```

Future:

```text
XiaozhiTransport
       ├── XiaozhiWebSocketTransport
       └── XiaozhiMqttUdpTransport
```

---

# 4. Recommended NotchHub package boundary

Xiaozhi protocol code SHALL NOT live in `NotchCore`, `NotchSurface`, or `NotchUI`.

Recommended structure:

```text
Modules/
└── XiaozhiModule/
    ├── Sources/
    │
    ├── Domain/
    │   ├── XiaozhiSessionState.swift
    │   ├── XiaozhiListeningMode.swift
    │   ├── XiaozhiMessage.swift
    │   ├── XiaozhiConfiguration.swift
    │   └── XiaozhiError.swift
    │
    ├── Identity/
    │   └── XiaozhiIdentityStore.swift
    │
    ├── Bootstrap/
    │   ├── XiaozhiBootstrapClient.swift
    │   ├── XiaozhiBootstrapRequest.swift
    │   └── XiaozhiBootstrapResponse.swift
    │
    ├── Transport/
    │   ├── XiaozhiTransport.swift
    │   ├── XiaozhiWebSocketTransport.swift
    │   └── XiaozhiBinaryFrameCodec.swift
    │
    ├── Session/
    │   ├── XiaozhiSessionController.swift
    │   └── XiaozhiMessageRouter.swift
    │
    ├── Audio/
    │   ├── XiaozhiAudioCapture.swift
    │   ├── XiaozhiAudioPlayback.swift
    │   ├── XiaozhiOpusEncoder.swift
    │   ├── XiaozhiOpusDecoder.swift
    │   └── XiaozhiAudioBuffer.swift
    │
    ├── MCP/
    │   └── XiaozhiMCPServer.swift
    │
    ├── State/
    │   └── XiaozhiStore.swift
    │
    └── UI/
        ├── XiaozhiVoiceView.swift
        └── XiaozhiTranscriptTicker.swift
```

Dependency direction:

```text
Xiaozhi UI
    ↓
Xiaozhi Store
    ↓
Xiaozhi Session Controller
    ↓
Bootstrap / Transport / Audio / MCP
    ↓
NotchDomain contracts
```

`NotchSurface` remains responsible only for presentation/window behavior.

---

# 5. Client identity

The upstream firmware sends two identity values consistently:

```http
Device-Id: ...
Client-Id: ...
```

They are used both during OTA/bootstrap and WebSocket connection.

## 5.1 Client-Id

Upstream generates a random UUID v4 once and persists it.

Equivalent NotchHub behavior:

```text
first launch
   ↓
generate UUID v4
   ↓
persist
   ↓
reuse on every launch
```

Recommended storage:

```text
Keychain:
com.notchhub.xiaozhi.client-id
```

`Client-Id` MUST remain stable across ordinary app restarts and upgrades.

Resetting Xiaozhi identity should be an explicit operation.

## 5.2 Device-Id

ESP32 uses its hardware MAC address as `Device-Id`.

This presents a compatibility question on macOS.

NotchHub SHALL NOT assume that the official Xiaozhi backend accepts an arbitrary UUID in this field until verified against the target service.

Recommended design:

```swift
struct XiaozhiIdentity {
    let deviceID: String
    let clientID: UUID
}
```

`deviceID` should come from an identity provider rather than being generated ad hoc inside the transport.

A stable app-scoped synthetic device identifier is preferable from a privacy and portability standpoint **if the Xiaozhi backend accepts it**.

Backend acceptance of the chosen format is a mandatory integration test.

---

# 6. Bootstrap / OTA discovery

The Xiaozhi firmware does not normally hardcode its active WebSocket server.

It first contacts the OTA/bootstrap endpoint.

Default upstream endpoint:

```text
https://api.tenclass.net/xiaozhi/ota/
```

The endpoint should nevertheless be configurable.

Recommended NotchHub setting:

```text
xiaozhi.bootstrapURL
```

## 6.1 Request

Upstream sends:

```http
Activation-Version: 1 or 2
Device-Id: <device-id>
Client-Id: <client-id>
User-Agent: ...
Accept-Language: ...
Content-Type: application/json
```

NotchHub should identify itself explicitly rather than pretending to be ESP32 firmware.

Example conceptual identity:

```text
User-Agent: NotchHub/X.Y macOS
```

The upstream client sends system/device information as JSON.

A macOS client should provide a compatibility payload representing NotchHub rather than inventing ESP flash/partition data unless the target backend requires those fields.

Conceptual payload:

```json
{
  "version": 2,
  "language": "en",
  "uuid": "<client-id>",
  "application": {
    "name": "NotchHub",
    "version": "0.x"
  },
  "board": {
    "type": "notchhub-macos"
  }
}
```

**Important:** the exact minimum payload accepted by the target Xiaozhi service must be determined by integration testing. Upstream documents the ESP32 payload, not a formal generic macOS bootstrap schema.

## 6.2 Response

NotchHub is interested primarily in:

```json
{
  "activation": {
    "message": "...",
    "code": "...",
    "challenge": "...",
    "timeout_ms": 0
  },
  "websocket": {
    "url": "wss://...",
    "token": "...",
    "version": 1
  },
  "server_time": {
    "...": "..."
  }
}
```

The actual response may omit sections.

The bootstrap parser MUST tolerate:

```text
activation absent
websocket absent
mqtt present
firmware metadata present
unknown future fields
```

Unknown fields must not cause decoding failure.

---

# 7. Activation

Activation is separate from the normal voice session.

Upstream behavior:

```text
bootstrap
   ↓
activation required?
   ├── no  -> continue
   │
   └── yes
        ↓
     show activation code/message
        ↓
 POST <bootstrap-url>/activate
        ↓
     202 -> pending
     200 -> activated
```

## 7.1 Hardware-HMAC activation

Some ESP32 devices use:

```json
{
  "algorithm": "hmac-sha256",
  "serial_number": "...",
  "challenge": "...",
  "hmac": "..."
}
```

This relies on device hardware/eFuse HMAC capabilities.

NotchHub MUST NOT simulate or fabricate this hardware identity mechanism.

For macOS:

```text
Activation-Version 1 / non-hardware activation
```

should be used if supported by the target backend.

If the backend requires hardware challenge authentication, a separate backend/client-registration mechanism will be required.

## 7.2 Activation UX

When activation is required:

```text
Xiaozhi Settings / detail window
 ├── activation message
 ├── activation code
 ├── connection status
 └── retry/cancel
```

Do not attempt to display an activation workflow entirely inside the compact Notch.

---

# 8. WebSocket connection

Once bootstrap provides a WebSocket configuration:

```text
websocket.url
websocket.token
websocket.version
```

NotchHub opens a WebSocket only when a conversation is needed.

This matches upstream's lazy connection model.

## 8.1 Required headers

Native client handshake:

```http
Authorization: Bearer <token>
Protocol-Version: <version>
Device-Id: <device-id>
Client-Id: <client-id>
```

If the received token already contains an authorization scheme, it should not receive another `Bearer ` prefix.

Production connection SHOULD use:

```text
wss://
```

## 8.2 Token handling

The token:

- MUST be treated as a secret.
- MUST NOT be written to `UserDefaults`.
- MUST NOT appear in diagnostics exports.
- MUST NOT appear in normal logs.
- SHOULD be kept in Keychain if it needs persistence.
- SHOULD be replaced atomically after successful bootstrap.

The native macOS client should use HTTP/WebSocket headers for credentials.

Do not copy browser-client workarounds that put credentials into query parameters unless absolutely required by the backend.

---

# 9. Client hello

Immediately after WebSocket connection, send the Xiaozhi `hello`.

Initial recommended Native Client hello:

```json
{
  "type": "hello",
  "version": 1,
  "features": {
    "mcp": true
  },
  "transport": "websocket",
  "audio_params": {
    "format": "opus",
    "sample_rate": 16000,
    "channels": 1,
    "frame_duration": 60
  }
}
```

Do not advertise capabilities that have not been implemented.

Examples:

```text
aec        -> advertise only when active and tested
glyph_push -> omit initially
mcp        -> true only if minimum MCP responder exists
```

## 9.1 Server hello

Expected response:

```json
{
  "type": "hello",
  "transport": "websocket",
  "session_id": "...",
  "audio_params": {
    "format": "opus",
    "sample_rate": 24000,
    "channels": 1,
    "frame_duration": 60
  }
}
```

Validation requirements:

```text
type == "hello"
transport == "websocket"
```

Store:

```text
session_id
server sample rate
server frame duration
```

Upstream waits approximately 10 seconds for server hello.

NotchHub should use the same compatibility timeout initially:

```text
helloTimeout = 10 seconds
```

Failure to receive valid hello returns the session to an error/idle state and closes the socket.

---

# 10. Session ID

The server owns `session_id`.

NotchHub MUST NOT invent it before server hello.

All subsequent control messages should include it:

```json
{
  "session_id": "...",
  "type": "..."
}
```

A reconnect creates a new transport session and may produce a new session ID.

Never reuse an old `session_id` after reconnect unless the backend explicitly specifies session resumption.

---

# 11. Audio contract

## 11.1 Microphone → server

Canonical upstream input:

```text
PCM
16,000 Hz
mono
16-bit signed
60 ms per Opus frame
```

At 16 kHz:

```text
16000 samples/sec × 0.060 sec
= 960 samples/frame
```

Therefore the capture pipeline is:

```text
Mac microphone
     ↓
native hardware sample rate
     ↓
resample
     ↓
16 kHz / mono / Int16
     ↓
optional processing
     ↓
960 samples
     ↓
Opus encoder
     ↓
WebSocket binary frame
```

Audio capture and WebSocket transmission MUST NOT run on the MainActor.

## 11.2 Opus encoder baseline

Upstream currently uses approximately:

```text
sample rate:        16 kHz
channels:           mono
frame duration:     60 ms
bitrate:            automatic
VBR:                enabled
DTX:                enabled
FEC:                disabled
application mode:   audio
```

Only the wire-level format/sample/frame requirements should be treated as interoperability requirements.

Codec tuning may differ on macOS after testing.

## 11.3 Server → speaker

Incoming WebSocket binary frames contain Opus audio.

Pipeline:

```text
WebSocket binary
     ↓
binary protocol parser
     ↓
Opus payload
     ↓
Opus decoder
     ↓
server sample rate
     ↓
resample if necessary
     ↓
Mac audio output
```

Do not assume 24 kHz permanently.

Use:

```text
server hello.audio_params.sample_rate
server hello.audio_params.frame_duration
```

as negotiated values.

---

# 12. Bounded audio buffers

Audio queues MUST be bounded.

Upstream limits include approximately:

```text
send Opus queue:
2400 ms / 60 ms = 40 packets

decode Opus queue:
1200 ms / 60 ms = 20 packets
```

NotchHub does not have to use identical sizes, but it MUST define explicit limits.

When the network cannot keep up:

```text
do not allow unbounded queue growth
```

Preferred policy for live voice:

```text
latency > perfect preservation
```

Old microphone packets may need to be dropped rather than allowing seconds of stale speech to accumulate.

Metrics should include:

```text
uplink queue depth
downlink queue depth
dropped uplink packets
dropped downlink packets
encode time
decode time
playback underruns
```

---

# 13. Binary protocol versions

WebSocket protocol defaults to version 1 upstream.

## Version 1

Binary WebSocket payload is raw Opus:

```text
| Opus payload |
```

This SHOULD be the initial NotchHub implementation.

## Version 2

Frame:

```text
uint16 version
uint16 type
uint32 reserved
uint32 timestamp
uint32 payload_size
uint8  payload[]
```

Network byte order is used for numeric fields.

This version provides timestamp metadata useful for server-side AEC.

## Version 3

Frame:

```text
uint8  type
uint8  reserved
uint16 payload_size
uint8  payload[]
```

## Implementation requirement

Use one codec abstraction:

```swift
protocol XiaozhiBinaryFrameCoding {
    func encodeAudio(_ packet: XiaozhiAudioPacket) throws -> Data
    func decodeAudio(_ data: Data) throws -> XiaozhiAudioPacket
}
```

Then:

```text
ProtocolV1FrameCodec
ProtocolV2FrameCodec
ProtocolV3FrameCodec
```

No protocol-version branching should leak into the UI or audio capture components.

---

# 14. Listening control messages

## Start listening

```json
{
  "session_id": "...",
  "type": "listen",
  "state": "start",
  "mode": "auto"
}
```

Supported modes:

```text
auto
manual
realtime
```

## Stop listening

```json
{
  "session_id": "...",
  "type": "listen",
  "state": "stop"
}
```

## Wake word detection

```json
{
  "session_id": "...",
  "type": "listen",
  "state": "detect",
  "text": "Hi XiaoZhi"
}
```

Wake word support is not required for the first Mac implementation.

A keyboard shortcut or Notch action can begin a session directly.

---

# 15. Listening modes

## 15.1 auto

Recommended first mode.

Flow:

```text
listening
   ↓ user stops talking
server processing
   ↓
TTS start
   ↓
speaking
   ↓
TTS stop
   ↓
listening again
```

This gives normal hands-free conversational behavior without requiring full-duplex AEC.

## 15.2 manual

Useful for push-to-talk.

```text
press
  ↓
listen/start manual
  ↓
capture
  ↓
release
  ↓
listen/stop
```

Recommended as the simplest diagnostic mode.

## 15.3 realtime

Full-duplex mode.

Upstream marks this mode as requiring AEC.

Therefore:

```text
MVP:
auto + manual

later:
realtime + validated AEC
```

NotchHub MUST NOT expose realtime mode as production-ready before echo cancellation has been tested with Mac speakers, headphones and external audio devices.

---

# 16. Abort / interruption

To interrupt current TTS:

```json
{
  "session_id": "...",
  "type": "abort"
}
```

Wake-word interruption may use:

```json
{
  "session_id": "...",
  "type": "abort",
  "reason": "wake_word_detected"
}
```

On local abort:

```text
stop/down-prioritize current playback
clear stale playback buffer
send abort
transition to listening or idle
```

depending on the user action.

---

# 17. Server JSON messages

The router should use a typed enum rather than allowing UI code to inspect arbitrary JSON.

Conceptually:

```swift
enum XiaozhiServerMessage {
    case hello(...)
    case stt(...)
    case tts(...)
    case llm(...)
    case mcp(...)
    case alert(...)
    case notify(...)
    case system(...)
    case custom(...)
    case unknown(...)
}
```

---

# 18. STT

Server:

```json
{
  "session_id": "...",
  "type": "stt",
  "text": "..."
}
```

Meaning:

```text
recognized user speech
```

NotchHub behavior:

```text
store current user transcript
publish module state
update transcript UI if visible
```

Do not treat STT as an instruction to execute an action.

---

# 19. TTS lifecycle

## TTS start

```json
{
  "session_id": "...",
  "type": "tts",
  "state": "start"
}
```

Transition:

```text
listening -> speaking
```

For non-realtime modes:

```text
stop/pause microphone upload
```

## Sentence start

```json
{
  "session_id": "...",
  "type": "tts",
  "state": "sentence_start",
  "text": "..."
}
```

This is the preferred source for current assistant text in the Notch ticker.

## TTS stop

```json
{
  "session_id": "...",
  "type": "tts",
  "state": "stop"
}
```

Behavior:

```text
manual mode:
speaking -> idle

auto mode:
speaking -> listening

realtime:
according to full-duplex session state
```

For auto mode, do not immediately start microphone capture while the local TTS playback queue still contains audio.

Wait until playback drains before returning to active voice processing.

This avoids the assistant's tail audio being captured as new user speech.

---

# 20. LLM state

Example:

```json
{
  "session_id": "...",
  "type": "llm",
  "emotion": "happy",
  "text": "😀"
}
```

For NotchHub:

```text
emotion -> optional UI state
text    -> optional metadata
```

Do not use LLM text as the primary assistant transcript when `tts.sentence_start.text` is available.

---

# 21. Alerts

Example:

```json
{
  "session_id": "...",
  "type": "alert",
  "status": "Warning",
  "message": "...",
  "emotion": "sad"
}
```

Recommended mapping:

```text
short alert -> Notch compact state
long/detail -> detail window
```

Alerts from a remote server must remain presentation data and must not automatically become privileged macOS actions.

---

# 22. System messages

ESP32 supports messages such as:

```json
{
  "type": "system",
  "command": "reboot"
}
```

NotchHub MUST NOT map a remote `reboot` message to rebooting macOS.

Initial policy:

```text
system/reboot -> unsupported / safely ignored + diagnostic event
```

If a future server command is mapped to application restart, it must pass through NotchHub's typed Action system and security policy.

---

# 23. MCP role

From the Xiaozhi backend's perspective, the Xiaozhi client exposes an MCP server.

Envelope:

```json
{
  "session_id": "...",
  "type": "mcp",
  "payload": {
    "jsonrpc": "2.0"
  }
}
```

Important methods:

```text
initialize
tools/list
tools/call
```

## 23.1 Initialization

Backend may send:

```json
{
  "jsonrpc": "2.0",
  "method": "initialize",
  "params": {},
  "id": 1
}
```

NotchHub responds with MCP version/capabilities.

## 23.2 Tool discovery

```json
{
  "jsonrpc": "2.0",
  "method": "tools/list",
  "params": {
    "cursor": "",
    "withUserTools": false
  },
  "id": 2
}
```

## 23.3 Tool call

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "...",
    "arguments": {}
  },
  "id": 3
}
```

---

# 24. MCP security boundary in NotchHub

Xiaozhi MCP MUST NOT directly execute:

```text
shell commands
AppleScript
arbitrary executable paths
unregistered closures
raw URLs with side effects
```

Required path:

```text
Xiaozhi MCP tools/call
        ↓
Xiaozhi MCP adapter
        ↓
registered NotchHub ActionID
        ↓
NotchActions
        ↓
validation
        ↓
permission check
        ↓
confirmation policy
        ↓
execution
```

Example future mapping:

```text
Xiaozhi:
notchhub.open_settings

      ↓

ActionID:
xiaozhi.openSettings
```

Only tools intentionally exposed by NotchHub may appear in `tools/list`.

The module should distinguish:

```text
AI-callable tools
user-only tools
```

in the same spirit as upstream's normal/user-only MCP tool separation.

---

# 25. Minimal MCP compatibility strategy

Because upstream advertises:

```json
"features": {
  "mcp": true
}
```

a compatible Native Xiaozhi Client should not advertise MCP unless it can at minimum process:

```text
initialize
tools/list
```

Initial valid strategy:

```text
initialize -> successful response
tools/list -> empty/safe tool list
tools/call unknown -> JSON-RPC method/tool error
```

Then NotchHub actions can be added incrementally.

---

# 26. Client state machine

Recommended state model:

```text
disabled
   │
   ▼
bootstrapping
   │
   ├── activationRequired
   │
   ▼
ready / idle
   │
   ▼
connecting
   │
   ▼
handshaking
   │
   ▼
listening
   │
   ▼
thinking
   │
   ▼
speaking
   │
   ├──────────► listening    auto
   │
   └──────────► idle         manual
```

Error states:

```text
bootstrapFailed
activationFailed
connectionFailed
handshakeFailed
audioFailed
protocolError
```

`thinking` is useful as a NotchHub presentation state even though the ESP32 state enum does not require an explicit thinking state.

---

# 27. Complete session sequence

```text
User                     NotchHub                       Xiaozhi
 │                          │                              │
 │ Start conversation       │                              │
 ├─────────────────────────►│                              │
 │                          │ ensure bootstrap config      │
 │                          │                              │
 │                          │ WSS connect                  │
 │                          ├─────────────────────────────►│
 │                          │                              │
 │                          │ hello                        │
 │                          ├─────────────────────────────►│
 │                          │                              │
 │                          │ server hello + session_id    │
 │                          ◄──────────────────────────────┤
 │                          │                              │
 │                          │ listen/start                 │
 │                          ├─────────────────────────────►│
 │                          │                              │
 │ speak                    │                              │
 │ ───────────────────────► │ Opus frames                  │
 │                          ├─────────────────────────────►│
 │                          │                              │
 │                          │ STT                          │
 │                          ◄──────────────────────────────┤
 │                          │                              │
 │                          │ TTS start                    │
 │                          ◄──────────────────────────────┤
 │                          │                              │
 │                          │ sentence_start               │
 │                          ◄──────────────────────────────┤
 │                          │                              │
 │                          │ Opus TTS frames              │
 │                          ◄──────────────────────────────┤
 │ hears reply              │                              │
 │                          │                              │
 │                          │ TTS stop                     │
 │                          ◄──────────────────────────────┤
 │                          │                              │
 │                          │ playback drain               │
 │                          │                              │
 │                          │ listen/start (auto continue) │
 │                          ├─────────────────────────────►│
```

---

# 28. WebSocket receive loop

The transport must continuously distinguish:

```text
text frame
    ↓
JSON decoder
    ↓
message router

binary frame
    ↓
binary protocol codec
    ↓
Opus decoder
    ↓
playback queue
```

Malformed JSON or malformed binary data should produce diagnostics and drop the individual frame where safe.

A single malformed message should not normally crash the module or app.

---

# 29. Connection lifetime

Follow upstream's lazy behavior:

```text
application launch
    ↓
bootstrap may run
    ↓
NO voice WebSocket required while idle
```

Open the voice WebSocket when:

```text
user invokes Xiaozhi
wake word fires
push-to-talk begins
explicit reconnect/test is requested
```

Close it when:

```text
conversation explicitly ends
network becomes unavailable
session fatally fails
module is disabled
app terminates
```

---

# 30. Timeout and reconnect

Compatibility baselines from upstream:

```text
server hello timeout: ~10 seconds
channel inactivity timeout: ~120 seconds
```

NotchHub should also implement network-aware reconnection.

Recommended policy:

```text
transient network error
       ↓
close transport cleanly
       ↓
cancel audio tasks
       ↓
clear session_id
       ↓
return to recoverable state
       ↓
retry with exponential backoff + jitter
```

Never continue sending microphone frames belonging to an old session after reconnect.

Reconnection must create a fresh transport/session handshake.

---

# 31. macOS sleep/wake

Before sleep:

```text
stop microphone capture
stop encoder task
stop playback task
close WebSocket
clear transient session
retain credentials/bootstrap config
```

After wake:

```text
refresh network state
do not automatically open microphone
return module to ready/idle
reconnect only when required
```

If an active user conversation is deliberately restored after wake, it should still use a new Xiaozhi session unless the backend explicitly supports resumption.

---

# 32. Microphone permission

Native Xiaozhi Client requires macOS microphone permission.

Permission request MUST be contextual.

Correct flow:

```text
user enables Native Xiaozhi
      ↓
explain microphone usage
      ↓
request permission
      ↓
granted?
 ├── yes -> voice capability available
 └── no  -> show recovery path
```

Do not request microphone access merely because NotchHub launches.

If permission is denied:

```text
module remains installed
connection diagnostics remain accessible
voice session cannot start
```

---

# 33. Audio concurrency

Recommended ownership:

```text
MainActor
 ├── user-visible session state
 └── UI updates

background actors/tasks
 ├── bootstrap HTTP
 ├── WebSocket receive
 ├── microphone capture
 ├── resampling
 ├── Opus encode
 ├── Opus decode
 └── playback scheduling
```

Do not route individual 60 ms audio frames through the application's general-purpose UI EventBus.

Audio requires a dedicated bounded streaming path.

Only summarized state changes should reach the UI event layer:

```text
xiaozhi.connection.changed
xiaozhi.session.changed
xiaozhi.voice.changed
xiaozhi.transcript.user
xiaozhi.transcript.assistant
xiaozhi.error
```

---

# 34. Suggested internal state

```swift
struct XiaozhiSessionSnapshot: Sendable {
    var connectionState: ConnectionState
    var voiceState: VoiceState

    var sessionID: String?

    var userText: String?
    var assistantText: String?
    var emotion: String?

    var protocolVersion: Int

    var inputSampleRate: Int
    var outputSampleRate: Int
    var frameDurationMS: Int

    var lastError: XiaozhiError?
}
```

No access token should appear in this snapshot.

---

# 35. Recommended actions

Eventually register typed actions such as:

```text
xiaozhi.start
xiaozhi.stop
xiaozhi.abort
xiaozhi.reconnect
xiaozhi.pushToTalk
xiaozhi.resetIdentity
```

`resetIdentity` is destructive and should require explicit confirmation because it may require Xiaozhi reactivation.

---

# 36. Settings

Recommended module settings:

```text
Enabled

Connection
├── bootstrap URL
├── connection status
├── activation status
└── reset client identity

Voice
├── listening mode
│   ├── auto
│   └── manual
├── input device
├── output device
└── microphone permission

Advanced
├── protocol version
├── diagnostics
└── reconnect
```

Do not expose token values in normal Settings UI.

Protocol version should normally be server/bootstrap controlled rather than manually changed by the user.

---

# 37. Notch presentation mapping

Suggested UI mapping:

```text
idle
-> no persistent expanded UI

connecting
-> subtle connection indicator

listening
-> microphone / listening animation

thinking
-> compact processing indicator

speaking
-> voice waveform/state

tts.sentence_start
-> running single-line Xiaozhi text

error
-> short error indicator
```

Long transcript/history belongs outside the Notch.

When output is muted, `tts.sentence_start.text` remains sufficient to display the response text even when TTS audio cannot be heard.

---

# 38. Diagnostics

Never log:

```text
Authorization header
access token
activation secrets
raw Keychain values
full authenticated URL
continuous raw microphone audio
```

Useful diagnostics:

```text
bootstrap result
selected transport
protocol version
connection state
hello latency
session ID redacted/hash
negotiated audio parameters
queue depths
dropped frame counters
encode/decode errors
WebSocket close code
last message type
reconnect count
```

Transcript logging should be disabled or redacted by default unless the user explicitly opts into diagnostic capture.

---

# 39. Security requirements

All data received from Xiaozhi SHALL be treated as remote/untrusted input.

Required controls:

```text
bounded JSON payload size
bounded binary frame size
strict binary header validation
payload_size <= actual data
known protocol versions only
bounded audio queues
no force unwrap on server fields
no arbitrary command execution
MCP Action allow-list
Keychain for secrets
diagnostic redaction
TLS/WSS in production
```

Remote `system`, `custom`, and MCP messages deserve the highest scrutiny.

---

# 40. Implementation phases

## NX0 — Protocol fixtures

Implement:

```text
Codable message models
hello parsing
STT/TTS parsing
binary V1 framing
session state reducer
fixtures/tests
```

No real microphone.

## NX1 — Bootstrap

Implement:

```text
identity persistence
OTA/bootstrap request
websocket config parsing
activation-state parsing
secure token storage
```

Verify against real backend.

## NX2 — WebSocket session

Implement:

```text
native WebSocket transport
headers
client hello
server hello
session ID
JSON receive loop
timeouts
disconnect handling
```

Still no microphone required.

## NX3 — Downlink audio

Implement:

```text
binary V1 reception
Opus decode
sample-rate conversion
bounded playback
TTS lifecycle
```

Use server-generated TTS to validate playback.

## NX4 — Uplink microphone

Implement:

```text
microphone permission
capture
mono conversion
16 kHz resample
60 ms framing
Opus encode
send queue
listen start/stop
```

At this point basic native conversation works.

## NX5 — Auto conversation

Implement:

```text
TTS -> speaking
playback drain
speaking -> listening
interrupt
abort
network recovery
```

## NX6 — MCP

Implement:

```text
initialize
tools/list
tools/call
NotchActions adapter
confirmation/security policy
```

## NX7 — Advanced audio

Evaluate:

```text
AEC
realtime mode
protocol V2 timestamping
audio route changes
headset/speaker edge cases
```

## NX8 — Production hardening

Validate:

```text
sleep/wake
offline/online
long conversations
token refresh/bootstrap refresh
malformed frames
server disconnect
audio-device switch
permission denial
module enable/disable
resource cleanup
performance
```

---

# 41. Test plan

## Unit tests

Must cover:

```text
Client-Id persistence
bootstrap request headers
bootstrap JSON decoding
activation decoding
WebSocket hello generation
server hello validation
session_id propagation
listen start/stop
abort
STT
TTS start
TTS sentence_start
TTS stop
LLM
MCP envelopes
V1 binary frames
V2 byte order
V3 byte order
invalid payload size
state-machine transitions
bounded queue behavior
secret redaction
```

## Fake-server integration tests

Build a deterministic local WebSocket test server capable of:

```text
accept connection
inspect request headers
receive hello
send hello
send STT
send TTS lifecycle
send binary Opus
drop connection
delay hello
send malformed frames
send MCP initialize
```

These tests should not require the production Xiaozhi cloud.

## Real backend tests

Mandatory before declaring compatibility:

```text
bootstrap accepted
Device-Id format accepted
Client-Id persisted
first-use activation
second launch without unnecessary reactivation
WebSocket auth accepted
hello accepted
manual listening
auto listening
microphone upload
STT received
TTS audio playback
TTS text received
abort
disconnect/reconnect
sleep/wake
```

---

# 42. Open compatibility questions

These points are **not completely specified by the xiaozhi-esp32 client repository** and must be verified against the actual backend used by NotchHub.

### Q1 — macOS Device-Id

Does the production Xiaozhi service require a physical MAC-shaped identifier, or can an application-defined stable identifier be used?

### Q2 — generic bootstrap payload

Which fields are actually mandatory for a non-ESP32 client?

### Q3 — activation

Does the service provide an Activation-Version 1 path suitable for desktop clients?

### Q4 — protocol version

Which WebSocket binary versions are currently enabled for the target backend?

### Q5 — MCP requirement

Will the backend tolerate a client that omits MCP capability, or should the first client include a minimal MCP responder?

### Q6 — token lifecycle

When should bootstrap be repeated and how long is the returned WebSocket token valid?

### Q7 — server-side AEC

What combination of:

```text
features.aec
Protocol-Version
timestamps
listening mode = realtime
```

is required by the selected backend?

These are integration-test questions, not assumptions to hardcode.

---

# 43. Definition of Done for first Native Xiaozhi Client

The first usable release is complete when this flow succeeds reliably:

```text
launch NotchHub
   ↓
load stable Xiaozhi identity
   ↓
bootstrap
   ↓
activate if required
   ↓
user invokes Xiaozhi
   ↓
open authenticated WebSocket
   ↓
client hello
   ↓
server hello + session ID
   ↓
listen/start auto
   ↓
Mac microphone PCM
   ↓
16 kHz mono / 60 ms
   ↓
Opus
   ↓
Xiaozhi
   ↓
STT
   ↓
TTS start
   ↓
text + binary Opus
   ↓
Notch text + Mac speaker
   ↓
TTS stop
   ↓
playback drain
   ↓
listen again
```

Additionally:

```text
no unbounded audio buffers
no secrets in logs
no microphone capture before permission/user intent
no remote arbitrary execution
clean shutdown
clean sleep/wake
clean reconnect
```

must all hold.

---

# 44. Required NotchHub architecture/document changes

The current NotchHub documentation treats Xiaozhi Display Companion/relay as the first Xiaozhi integration and native voice as a later phase.

Adopting this document as the target architecture therefore requires an explicit project decision.

Recommended new ADR:

```text
docs/architecture/decisions/
0014-use-native-xiaozhi-client.md
```

The ADR should state:

```text
Decision:
NotchHub will implement Xiaozhi as a native macOS client capable of
bootstrap, authenticated WebSocket sessions, microphone capture,
Opus transport, TTS playback, transcript presentation, and controlled
MCP integration.

Consequences:
- Microphone becomes an actual module permission.
- Xiaozhi credentials become first-class secrets.
- Direct outbound network connectivity enters the threat model.
- Audio streaming enters the performance model.
- The previous relay-only M1 assumption is superseded.
- MCP must cross NotchActions rather than executing arbitrary operations.
```

Documents that must subsequently be reconciled:

```text
README.md
docs/product/vision.md
docs/product/roadmap.md
docs/product/requirements.md
docs/architecture/overview.md
docs/architecture/c4-context.md
docs/architecture/c4-container.md
docs/architecture/module-system.md
docs/architecture/performance.md
docs/platform/permissions.md
docs/security/threat-model.md
docs/quality/testing-strategy.md
docs/index.md
```

---

# 45. Final implementation rule

Xiaozhi wire protocol and audio transport belong to the Xiaozhi module.

The stable NotchHub platform should receive only normalized domain state:

```text
Xiaozhi network/audio
        ↓
XiaozhiSessionController
        ↓
XiaozhiStore
        ↓
normalized module events/state
        ↓
Notch presentation
```

Never make `NotchSurface` understand:

```text
WebSocket
Opus
session_id
MCP
OTA
Authorization tokens
```

and never make transport code understand:

```text
NSPanel
Notch geometry
SwiftUI animation
hover behavior
```

That separation is the central boundary required to keep Native Xiaozhi support maintainable.