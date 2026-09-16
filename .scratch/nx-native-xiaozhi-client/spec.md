# NX — Native Xiaozhi Client

Status: ready-for-agent

## Problem Statement

NotchHub cần một Native Xiaozhi Client hoàn chỉnh thay cho hai phase M1 relay/display và M5 native voice. Người dùng cần bắt đầu và điều khiển hội thoại Xiaozhi từ macOS mà không làm Notch surface biết raw protocol, secret, hoặc audio frame; đồng thời microphone, Settings, audio/network, privacy và lifecycle phải theo các platform contracts hiện có.

## Solution

Hoàn thiện static `XiaozhiModule` sau seam `ModuleRuntime → XiaozhiModule`. Module trực tiếp bootstrap vào Xiaozhi Cloud, thực hiện authenticated WebSocket session, Microphone/Opus uplink, TTS/Opus downlink, state projection và điều khiển Auto/Push-to-Talk. Module chỉ công bố bounded normalized state cho Notch surface; Settings store giữ non-secret module settings, Permission Coordinator sở hữu consent, và Keychain sở hữu secret. MVP không có MCP hoặc transcript persistence.

## User Stories

1. As a Mac user, I want to enable the Native Xiaozhi Client, so that I can use Xiaozhi without a relay or ESP32 companion.
2. As a Mac user, I want the module to become ready at launch without opening my microphone, so that launch remains private and quiet.
3. As a Mac user, I want to explicitly start a conversation, so that network and microphone use always follow my intent.
4. As a Mac user, I want to choose Auto or Push-to-Talk, so that the conversation behavior matches my preference.
5. As a Mac user, I want a contextual microphone explanation and macOS permission prompt, so that I understand when audio can leave my Mac.
6. As a Mac user, I want a recovery path when microphone access is denied or revoked, so that I can fix it without repeated prompts.
7. As a Mac user, I want a stable device identity and the requested `test-client` client identity, so that the backend can recognize this installation during testing.
8. As a Mac user, I want the generated locally-administered MAC Device-ID to survive relaunch, so that it does not change per connection.
9. As a Mac user, I want bootstrap and activation feedback, so that I know whether the selected Xiaozhi Cloud backend accepts my device.
10. As a Mac user, I want connection, listening, thinking, speaking, and error states, so that the Notch surface gives useful compact feedback.
11. As a Mac user, I want microphone speech encoded and sent with bounded latency, so that the assistant receives current speech rather than stale audio.
12. As a Mac user, I want TTS audio played through the chosen output route, so that I can hear the assistant response.
13. As a Mac user, I want to abort an assistant response, so that I can interrupt it safely.
14. As a Mac user, I want reconnect and sleep/wake recovery to discard stale session/audio state, so that a new session is clean.
15. As a Mac user, I want assistant and user transcript text only for the active session, so that conversation history is not retained by default.
16. As a Mac user, I want one-line camera-safe assistant text when muted, so that a response remains understandable without audible TTS.
17. As a Mac user, I want durable Xiaozhi Settings in the Settings application scene, so that configuration persists without exposing secrets.
18. As a Mac user, I want expanded Notch content to contain only immediate conversation controls, so that it remains a short-form Notch surface.
19. As a privacy-conscious user, I want tokens and credentials excluded from settings, logs, diagnostics, and exports, so that remote access cannot leak.
20. As a developer, I want deterministic fake-server and protocol fixtures, so that protocol, reconnect, malformed input, and secret-redaction behavior can be tested without Xiaozhi Cloud.
21. As a developer, I want real Xiaozhi Cloud acceptance checks, so that unverified assumptions about activation, Device-ID, and protocol versions are not shipped as facts.
22. As a maintainer, I want module disable/failure to cancel owned audio/network resources, so that the App shell remains healthy.

## Implementation Decisions

- `NX` replaces M1 and M5, per ADR-0018; it is one static native macOS Module and connects directly to the default Xiaozhi Cloud bootstrap service. A custom bootstrap URL is advanced and has no compatibility guarantee.
- The highest feature seam is `ModuleRuntime → XiaozhiModule`. Module runtime remains the only lifecycle authority; the module receives lifetime, Action Registry and Module event publisher through ModuleContext.
- The module prepares to `ready` at launch. A user Action is required before a voice WebSocket connection or microphone capture begins.
- The current foundation retains a hard-coded Client-ID `test-client`. Device-ID is a locally-administered unicast MAC string generated once and persisted in the versioned Settings snapshot.
- Xiaozhi non-secret settings include prepared-on-launch, auto reconnect, conversation mode, and Device-ID. They are validated and migrated by the Settings store. Credentials, activation state tied to credential, and bearer tokens are Keychain-owned Secrets.
- Permission Coordinator must accept a declared `xiaozhi` microphone requirement and use the native microphone adapter. The module never prompts directly.
- Transport uses the existing Xiaozhi transport seam with WebSocket text/binary events. It must send required identity/auth headers, make disconnect idempotent, and cancel receive work through the Module lifetime.
- Audio uses native AVFoundation for capture/playback and PCM conversion. Official libopus 1.6.1, vendored with a pinned checksum and reproducible XCFramework build, is the only external codec dependency behind a thin internal Swift wrapper. Uplink normalizes to 16 kHz mono signed-Int16, creates 60 ms frames, encodes Opus, and bounds queued audio to about 2400 ms. Downlink decodes Opus using negotiated server audio parameters, bounds playback to about 1200 ms, and drops stale audio under pressure.
- The Session Controller owns bootstrap, activation, hello/session-ID negotiation, listen/start-stop, STT, TTS, abort, playback drain, reconnect, and sleep/wake state transitions. It clears session ID and all transient audio before reconnect.
- Notch surface receives only normalized presentation state through a bounded Module state projection. It does not receive raw WebSocket messages, Opus packets, session IDs, authorization data, or transport errors containing secrets.
- Assistant/user transcript is Conversation transcript session memory only. It is cleared on normal completion, abort, disable, failure, reconnect, and sleep. No history, detail window, or cloud sync belongs to MVP.
- MCP is excluded. Any later MCP capability requires a separate ADR before tools/calls are exposed.

## Testing Decisions

- Test externally observable lifecycle, Settings, permission, transport, session and presentation outcomes; do not test private task/layout details.
- Prefer the existing ModuleRuntime seam for enable/start/disable/failure/resource-revocation behavior. Existing ModuleRuntime and DemoModule tests are prior art.
- Test Settings store migration from schema v3 to NX settings schema, Device-ID validation/persistence, malformed ID rejection, future-schema read-only recovery, and sanitized export with no Secret.
- Test Permission Coordinator with fake adapters for passive-request rejection, confirmed microphone request, denial/revocation recovery, and no prompt at launch. Existing permission tests are prior art.
- Use a deterministic local fake WebSocket server to assert headers, client hello, session negotiation, listen/abort, STT/TTS routing, delayed hello, disconnect, malformed JSON/binary, and reconnect behavior.
- Test bounded uplink/downlink queues by observing stale-frame drop counters and current-frame delivery rather than internal buffer implementation.
- Test redaction through diagnostics/settings export fixtures containing token-like values and transcript/audio payloads.
- Run real backend acceptance for bootstrap, Device-ID, activation, authenticated WebSocket, Auto/PTT, microphone/STT, TTS audio/text, abort, reconnect, and sleep/wake.
- Require native macOS QA for microphone prompt/revocation, selected audio routes, muted transcript behavior, Notch compact/expanded controls, VoiceOver, and module disable during active audio.

## Out of Scope

- MQTT/UDP transport, wake word, realtime full duplex, production AEC, camera/vision, advanced audio route policy, cloud transcript history, MCP, arbitrary remote execution, and custom endpoint compatibility certification.
- A relay, ESP32 observer architecture, raw protocol in Notch surface, raw audio in the shared EventBus, unbounded queues, UserDefaults/module-private settings files, secret storage in Settings, AudioKit, FFmpeg, libopusenc, Alamofire, Starscream, and third-party Swift Opus wrappers.

## Further Notes

The repository already contains the NX package scaffold, WebSocket transport seam, microphone adapter, versioned Xiaozhi Settings, generated MAC Device-ID validation, and focused identity/settings tests. Opus codec integration, AVFoundation audio pipeline, bootstrap/activation, session controller, UI integration, Keychain owner, fake server, and real-backend/native qualification remain to be implemented. The user confirmed prior Foundation native/manual QA, but NX has separate real-audio and real-backend evidence gates.
