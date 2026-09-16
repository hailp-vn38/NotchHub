# Native Xiaozhi Client
## Architecture, Connection, Audio, Protocol & Settings Specification for NotchHub

**Status:** Draft / Architecture Specification
**Target platform:** macOS 14+
**Target project:** NotchHub
**Module:** Native Xiaozhi Client
**Primary upstream reference:** `78/xiaozhi-esp32`
**Preferred transport:** WebSocket
**Initial conversation modes:** Auto + Push-to-Talk
**Initial audio:** Microphone input + TTS playback

---

## Chốt thiết kế (2026-09-15)

- Backend chuẩn để tích hợp và kiểm thử MVP là Xiaozhi Cloud mặc định. Custom bootstrap URL là Advanced setting, không mang cam kết tương thích.
- Module có thể chuẩn bị đến `ready` khi launch, nhưng chỉ mở WebSocket hoặc microphone sau một Action do người dùng chủ động kích hoạt.
- MCP không thuộc MVP hiện tại.
- Xiaozhi sở hữu schema, validation và Settings application-scene UI của mình; Settings store persist phần non-secret như một entry versioned theo ModuleID. Device ID và Client ID có thể chỉnh sửa; token chỉ sống trong memory của session/test và không dùng Keychain.
- Transcript chỉ sống trong memory của session, không có persistent history ở MVP.
- Expanded Notch surface chỉ hiển thị trạng thái và điều khiển hội thoại tức thời. Settings và Diagnostics bền vững ở application scene.

---

# 1. Mục tiêu

Module Xiaozhi của NotchHub được xây dựng như một **Native Xiaozhi Client trên macOS**.

NotchHub tự kết nối trực tiếp tới Xiaozhi backend:

```text
Mac Microphone
      │
      ▼
 NotchHub
 Native Xiaozhi Client
      │
      │ HTTPS Bootstrap
      │ WebSocket JSON + Opus
      ▼
 Xiaozhi Backend
      │
      ├── STT
      ├── LLM
      ├── TTS
      └── MCP
      │
      ▼
 NotchHub
      ├── Notch UI
      └── Mac Audio Output
```

NotchHub không đóng vai trò observer của một thiết bị ESP32 khác.

Không sử dụng kiến trúc:

```text
ESP32
  ↓
Xiaozhi Server
  ↓
Relay
  ↓
NotchHub
```

Thay vào đó:

```text
NotchHub
  ↓
Xiaozhi Server
```

NotchHub trở thành một Xiaozhi client độc lập, có session riêng.

---

# 2. Phạm vi phiên bản đầu

Native Xiaozhi Client phiên bản đầu cần hỗ trợ:

```text
Bootstrap
Activation
WebSocket
Client/Server Hello
Session ID
Microphone
Opus Encode
STT
TTS
Opus Decode
Audio Playback
Auto Conversation
Push-to-Talk
Abort
Reconnect
Notch Voice UI
Transcript Ticker
```

Chưa cần:

```text
MQTT + UDP
Wake Word
Realtime Full Duplex
Production AEC
Camera/Vision
Advanced MCP tools
Conversation history cloud sync
```

---

# 3. Kiến trúc module

Protocol Xiaozhi không được đặt trong:

```text
NotchCore
NotchSurface
NotchUI
```

Đề xuất:

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
    ├── State/
    │   └── XiaozhiStore.swift
    │
    └── UI/
        ├── XiaozhiVoiceView.swift
        └── XiaozhiTranscriptTicker.swift
```

Dependency:

```text
Xiaozhi UI
    ↓
Xiaozhi Store
    ↓
Xiaozhi Session Controller
    ↓
Transport / Bootstrap / Audio
    ↓
NotchDomain
```

`NotchSurface` chỉ biết state để hiển thị.

Nó không được biết:

```text
WebSocket
Opus
session_id
Authorization Token
OTA
MCP internals
```

---

# 4. Transport

Phiên bản đầu sử dụng:

```text
WebSocket
```

Không sử dụng MQTT + UDP.

WebSocket phù hợp vì cùng một connection mang:

```text
JSON control messages
+
binary Opus audio
```

Định nghĩa transport abstraction:

```swift
protocol XiaozhiTransport: Sendable {
    var events: AsyncStream<XiaozhiTransportEvent> { get }

    func connect(
        configuration: XiaozhiConnectionConfiguration
    ) async throws

    func send(text: Data) async throws

    func send(binary: Data) async throws

    func disconnect() async
}
```

Ban đầu:

```text
XiaozhiTransport
      │
      └── XiaozhiWebSocketTransport
```

Tương lai có thể thêm:

```text
XiaozhiMqttUdpTransport
```

mà không ảnh hưởng Session/UI.

---

# 5. Client Identity

Xiaozhi sử dụng:

```http
Device-Id
Client-Id
```

## 5.1 Client ID

NotchHub tạo UUID v4 duy nhất khi client được khởi tạo.

```text
First Setup
   ↓
UUID v4
   ↓
Persist
   ↓
Reuse
```

Client ID không được thay đổi sau mỗi lần khởi động.

Lưu trong `XiaozhiSettings`; chỉ persist sau khi người dùng Apply.

Ví dụ:

```text
com.notchhub.xiaozhi.client-id
```

Reset Client ID là thao tác destructive.

---

# 6. Device ID

ESP32 sử dụng hardware MAC address.

Trên macOS không nên cố giả lập hardware MAC ESP32.

Đề xuất abstraction:

```swift
struct XiaozhiIdentity {
    let deviceID: String
    let clientID: UUID
}
```

`Device-Id` phải:

```text
stable
privacy-safe
persistent
```

nhưng cần kiểm tra thực tế xem backend Xiaozhi chấp nhận format nào.

Không hardcode giả định rằng UUID luôn được chấp nhận.

---

# 7. Bootstrap

Xiaozhi client trước tiên gọi OTA/bootstrap endpoint để lấy cấu hình connection.

Default upstream hiện dùng:

```text
https://api.tenclass.net/xiaozhi/ota/
```

NotchHub dùng URL này làm backend chuẩn của MVP. URL có thể configurable trong Advanced settings, nhưng custom endpoint không có cam kết tương thích.

Setting nội bộ:

```text
xiaozhi.bootstrapURL
```

---

# 8. Bootstrap request

Headers:

```http
Activation-Version: 1
Device-Id: <device-id>
Client-Id: <client-id>
User-Agent: NotchHub/<version> macOS
Accept-Language: <language>
Content-Type: application/json
```

NotchHub không nên giả danh ESP32 firmware.

Payload nên mô tả client thật:

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

Các field thực sự bắt buộc phải được xác nhận bằng integration test với backend.

---

# 9. Bootstrap response

Quan tâm chủ yếu đến:

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
  }
}
```

Parser phải chịu được:

```text
missing activation
missing websocket
mqtt data present
unknown fields
future fields
```

Không fail toàn bộ response chỉ vì xuất hiện field mới.

---

# 10. Activation

Flow:

```text
Bootstrap
   ↓
Activation required?
   │
   ├── No
   │    ↓
   │   Ready
   │
   └── Yes
        ↓
Show activation code
        ↓
POST /activate
        ↓
200 = Success
202 = Pending
```

Hardware HMAC activation trên ESP32 không nên được giả lập trên Mac.

Nếu backend yêu cầu hardware challenge/HMAC, cần một flow desktop riêng.

---

# 11. WebSocket Connection

Sau bootstrap, sử dụng:

```text
websocket.url
websocket.token
websocket.version
```

Headers:

```http
Authorization: Bearer <token>
Protocol-Version: <version>
Device-Id: <device-id>
Client-Id: <client-id>
```

Nếu token đã bao gồm scheme, không thêm `Bearer` lần nữa.

Production phải ưu tiên:

```text
wss://
```

---

# 12. Secret handling

Token:

```text
Không lưu UserDefaults
Không log
Không export diagnostics
Không hiển thị Settings
Không đưa vào domain snapshot
```

Token không được persist. Mỗi session, Restart hoặc Test Connection bootstrap lại để nhận token mới.

---

# 13. Client Hello

Sau khi WebSocket connect:

```json
{
  "type": "hello",
  "version": 1,
  "features": {},
  "transport": "websocket",
  "audio_params": {
    "format": "opus",
    "sample_rate": 16000,
    "channels": 1,
    "frame_duration": 60
  }
}
```

Chỉ advertise những capability thật sự implement.

Ví dụ:

```text
mcp
aec
glyph_push
```

không được khai báo `true` nếu chưa hoạt động.

---

# 14. Server Hello

Server trả:

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

Client lưu:

```text
session_id
server_sample_rate
server_frame_duration
```

Không hardcode output sample rate = 24000.

Luôn lấy từ server hello.

Timeout ban đầu:

```text
10 seconds
```

---

# 15. Session ID

Server tạo Session ID.

Client không tự generate.

Các message sau đó gửi:

```json
{
  "session_id": "...",
  "type": "..."
}
```

Reconnect:

```text
clear old session ID
create new connection
perform hello again
receive new session ID
```

Không reuse session cũ.

---

# 16. Audio input

Chuẩn upstream:

```text
PCM
16000 Hz
Mono
Signed Int16
60 ms / frame
```

Tức:

```text
16000 × 0.06
=
960 samples/frame
```

Pipeline:

```text
Mac Microphone
      ↓
Hardware sample rate
      ↓
Resampler
      ↓
16kHz Mono Int16
      ↓
960 samples
      ↓
Opus Encoder
      ↓
WebSocket binary
```

Audio processing không chạy trên MainActor.

---

# 17. Opus Encoder

Baseline:

```text
Sample rate       16 kHz
Channels          Mono
Frame             60 ms
Bitrate           Auto
VBR               Enabled
DTX               Enabled
FEC               Disabled
Application       Audio
```

Settings UI không expose các giá trị này.

Đây là implementation details.

---

# 18. Audio output

Pipeline:

```text
WebSocket Binary
      ↓
Binary Frame Decoder
      ↓
Opus
      ↓
Opus Decoder
      ↓
Server Sample Rate
      ↓
Resampler nếu cần
      ↓
Mac Audio Output
```

---

# 19. Bounded buffers

Không cho phép audio queue tăng vô hạn.

Baseline tương tự upstream:

```text
Uplink:
~2400 ms maximum

Downlink:
~1200 ms maximum
```

Có thể thay đổi sau profiling.

Nguyên tắc:

```text
Low latency > preserving stale voice frames
```

Nếu queue quá lớn, drop stale packets thay vì tạo conversation delay nhiều giây.

---

# 20. WebSocket binary protocol

## Protocol V1

MVP dùng:

```text
| Raw Opus Payload |
```

Đây là implementation đầu tiên nên hỗ trợ.

## Protocol V2

```text
uint16 version
uint16 type
uint32 reserved
uint32 timestamp
uint32 payload_size
payload
```

## Protocol V3

```text
uint8 type
uint8 reserved
uint16 payload_size
payload
```

Nên dùng abstraction:

```swift
protocol XiaozhiBinaryFrameCoding {
    func encodeAudio(
        _ packet: XiaozhiAudioPacket
    ) throws -> Data

    func decodeAudio(
        _ data: Data
    ) throws -> XiaozhiAudioPacket
}
```

---

# 21. Listening

Start:

```json
{
  "session_id": "...",
  "type": "listen",
  "state": "start",
  "mode": "auto"
}
```

Stop:

```json
{
  "session_id": "...",
  "type": "listen",
  "state": "stop"
}
```

Modes:

```text
auto
manual
realtime
```

---

# 22. Conversation modes cho NotchHub

Settings chỉ expose ban đầu:

```text
Auto
Push to Talk
```

Mapping:

```text
Auto
→ Xiaozhi auto

Push to Talk
→ Xiaozhi manual
```

Không expose Realtime ban đầu.

Realtime cần:

```text
AEC
full duplex validation
speaker/headphone testing
```

---

# 23. Abort

Message:

```json
{
  "session_id": "...",
  "type": "abort"
}
```

Khi user interrupt:

```text
stop playback
clear stale playback data
send abort
transition to listening/idle
```

---

# 24. STT

Server:

```json
{
  "type": "stt",
  "text": "..."
}
```

Ý nghĩa:

```text
Recognized user speech
```

Store:

```text
currentUserTranscript
```

STT chỉ là transcript.

Không được tự động execute Action từ STT.

---

# 25. TTS

## Start

```json
{
  "type": "tts",
  "state": "start"
}
```

State:

```text
Listening
   ↓
Speaking
```

## Sentence Start

```json
{
  "type": "tts",
  "state": "sentence_start",
  "text": "..."
}
```

Đây là nguồn chính cho Xiaozhi assistant text trên Notch.

## Stop

```json
{
  "type": "tts",
  "state": "stop"
}
```

Auto mode:

```text
Speaking
   ↓
Playback Drain
   ↓
Listening
```

Manual:

```text
Speaking
   ↓
Idle
```

Không mở microphone ngay khi nhận `tts.stop` nếu audio local vẫn chưa phát xong.

---

# 26. LLM

Ví dụ:

```json
{
  "type": "llm",
  "emotion": "happy"
}
```

Có thể dùng:

```text
emotion
→ UI metadata
```

Không dùng nó thay cho transcript nếu đã có:

```text
tts.sentence_start.text
```

---

# 27. MCP (Future)

MCP không thuộc MVP hiện tại. Client không advertise capability `mcp`, không implement MCP server, và không nhận `mcp` message như một phần của conversation flow.

Nếu được đưa vào một phase sau, nó phải có ADR riêng để chốt action allow-list, confirmation policy, request bounds và audit model trước khi triển khai. Phần còn lại của mục này chỉ là thiết kế tham khảo cho phase đó.

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

Cần hỗ trợ tối thiểu:

```text
initialize
tools/list
tools/call
```

MVP:

```text
initialize
→ success

tools/list
→ safe/empty list

unknown tools/call
→ proper JSON-RPC error
```

---

# 28. MCP Security

Không cho Xiaozhi gọi trực tiếp:

```text
Shell
AppleScript
Executable
Filesystem arbitrary
Raw Swift closure
System command
```

Luồng bắt buộc:

```text
Xiaozhi MCP
    ↓
Xiaozhi MCP Adapter
    ↓
NotchHub ActionID
    ↓
NotchActions
    ↓
Validation
    ↓
Permission
    ↓
Confirmation
    ↓
Execution
```

Chỉ registered actions mới được expose.

---

# 29. System messages

Ví dụ upstream:

```json
{
  "type": "system",
  "command": "reboot"
}
```

Trên Mac:

```text
reboot
→ Unsupported
```

Không được reboot macOS.

Nếu tương lai muốn restart app:

```text
Remote message
→ typed action
→ confirmation policy
```

---

# 30. Session state machine

Recommended:

```text
disabled
   ↓
bootstrapping
   ↓
activationRequired
   ↓
ready
   ↓
connecting
   ↓
handshaking
   ↓
listening
   ↓
thinking
   ↓
speaking
   ├─────────────→ listening
   │                 auto
   │
   └─────────────→ idle
                     manual
```

Errors:

```text
bootstrapFailed
activationFailed
connectionFailed
handshakeFailed
audioFailed
protocolError
```

---

# 31. State snapshot

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

Không chứa token.

---

# 32. Full conversation flow

```text
User
 │
 │ Start Xiaozhi
 ▼
NotchHub
 │
 │ Bootstrap if needed
 ▼
WebSocket Connect
 │
 │ Client Hello
 ▼
Xiaozhi
 │
 │ Server Hello
 │ session_id
 ▼
NotchHub
 │
 │ listen/start
 │
 │ microphone → Opus
 ▼
Xiaozhi
 │
 │ STT
 ▼
NotchHub
 │
 │ Thinking
 ▼
Xiaozhi
 │
 │ TTS start
 │ sentence_start
 │ Opus audio
 ▼
NotchHub
 │
 │ Speaking UI
 │ transcript
 │ speaker output
 ▼
TTS stop
 │
 ▼
Playback drained
 │
 ▼
Listening again
```

---

# 33. Connection lifecycle

Không mở WebSocket voice liên tục nếu không cần.

Open khi:

```text
Start conversation
Push-to-talk
Reconnect
Future wake word
```

Close khi:

```text
Conversation ends
Network offline
Module disabled
Fatal protocol error
App termination
Sleep
```

---

# 34. Reconnect

Flow:

```text
Connection Error
      ↓
Stop Audio
      ↓
Clear session ID
      ↓
Close Transport
      ↓
Recoverable State
      ↓
Backoff + Jitter
      ↓
New WebSocket Session
```

Không gửi audio cũ sau reconnect.

---

# 35. Sleep/Wake

Before sleep:

```text
stop microphone
stop encoder
stop playback
close socket
clear transient session
```

Persist:

```text
client ID
settings
credentials
bootstrap configuration
```

After wake:

```text
ready
```

Không tự bật microphone.

---

# 36. Microphone Permission

Không request khi app launch.

Flow:

```text
User enables Xiaozhi
      ↓
Explain requirement
      ↓
Request Microphone
      ↓
Granted?
   ├── Yes
   │    ↓
   │   Voice available
   │
   └── No
        ↓
       Recovery UI
```

Permission do global `PermissionCoordinator` quản lý.

Module không tạo permission subsystem riêng.

---

# 37. Concurrency

```text
MainActor
├── Session UI state
├── Settings UI
└── Notch rendering

Background
├── HTTP Bootstrap
├── WebSocket
├── Microphone
├── Resampling
├── Opus Encode
├── Opus Decode
└── Playback
```

Không gửi từng audio frame qua EventBus chung.

EventBus chỉ nhận state-level events:

```text
xiaozhi.connection.changed
xiaozhi.session.changed
xiaozhi.voice.changed
xiaozhi.transcript.user
xiaozhi.transcript.assistant
xiaozhi.error
```

---

# 38. Settings Information Architecture

Module có một trang chính:

```text
Settings
└── Modules
    └── Xiaozhi
```

Không tạo quá nhiều sub-page.

Trang chính chia thành:

```text
Overview
General
Voice
Audio
Notch Behavior
Connection
Permissions
Privacy
Advanced
Diagnostics
```

---

# 39. Header / Overview

Phần đầu:

```text
Xiaozhi
Native Xiaozhi Client

● Connected

Enabled                         [✓]
```

Status có thể là:

```text
Disabled
Ready
Connecting
Connected
Listening
Thinking
Speaking
Activation Required
Error
```

---

# 40. General Settings

```text
GENERAL

Start Xiaozhi on launch        [✓]

Auto reconnect                 [✓]

Conversation Mode              Auto >
```

`Start Xiaozhi on launch` chỉ chuẩn bị module đến `ready`; nó không mở WebSocket voice và không mở microphone.

Conversation Mode:

```text
Auto
Push to Talk
```

Không expose Realtime lúc đầu.

---

# 41. Voice Settings

```text
VOICE

Microphone
MacBook Microphone             >

Input Level
████████░░

Interrupt Xiaozhi response     [✓]

Continue conversation          [✓]
```

`Continue conversation` tương ứng Auto mode.

Có thể disable hoặc ẩn setting này khi mode = Push to Talk.

---

# 42. Audio Settings

```text
AUDIO

Input Device
MacBook Microphone             >

Output Device
MacBook Speakers               >

Play connection sounds         [✓]

Show transcript when muted     [✓]
```

Không nên tạo custom volume slider cho Xiaozhi ở MVP nếu audio playback sử dụng system output volume.

Tốt hơn dùng system audio behavior nhất quán.

---

# 43. Muted Behavior

Khi system audio muted:

```text
TTS Audio
   ↓
Cannot be heard

tts.sentence_start.text
   ↓
Notch transcript ticker
```

Default:

```text
Show transcript when muted = On
```

Đây là behavior quan trọng của NotchHub Xiaozhi.

---

# 44. Notch Behavior Settings

```text
NOTCH BEHAVIOR

Listening Display              Voice Activity >

Speaking Display               Voice Activity >

When Muted                     Scrolling Text >

Show User Transcript           [ ]

Show Xiaozhi Text              [✓]
```

## Listening Display

Options:

```text
Voice Activity
Waveform
Minimal Indicator
```

Recommended default:

```text
Voice Activity
```

## Speaking Display

Options:

```text
Voice Activity
Minimal Indicator
Text
```

Recommended:

```text
Voice Activity
```

## When Muted

Options:

```text
Scrolling Text
Voice Indicator Only
Nothing
```

Recommended:

```text
Scrolling Text
```

---

# 45. Notch visual defaults

Design mặc định:

```text
Listening
→ Voice state only

Speaking
→ Voice state only

Muted
→ One-line scrolling Xiaozhi text
```

Transcript ticker:

```text
single line
no wrap
no second line
continuous movement
camera-safe
```

Text không được chạy dưới physical camera notch.

UI layout phải dành vùng an toàn quanh camera cluster.

---

# 46. Connection Settings

```text
CONNECTION

Status                Connected

Activation            Activated

Client ID             7A39••••B21C

Server                Xiaozhi Cloud

[ Reconnect ]
```

Client ID:

```text
masked by default
```

Có action:

```text
Copy Client ID
```

Không hiển thị:

```text
Session ID
Token
Authorization Header
```

trong UI chính.

---

# 47. Activation UI

Chỉ hiện khi activation required:

```text
ACTIVATION REQUIRED

Connect this Mac to Xiaozhi.

Activation Code

       8 4 2 9 1 6

Waiting for activation…

[ Retry ]
```

Sau thành công:

```text
Activation
Activated
```

Không lưu/display activation code sau đó.

---

# 48. Permissions

Trang module chỉ hiển thị trạng thái:

```text
PERMISSIONS

Microphone             Allowed >
```

Nếu chưa có:

```text
Microphone
Required for Xiaozhi Voice

[ Allow Microphone ]
```

Button dẫn vào global Permission Coordinator.

Ownership:

```text
NotchHub Permission Center
```

không phải Xiaozhi riêng.

---

# 49. Privacy

```text
PRIVACY

Microphone audio is sent only
during an active Xiaozhi conversation.

Store conversation transcript    [ ]

[ Clear Local Transcript ]
```

MVP không lưu transcript hay conversation history. Transcript chỉ tồn tại trong memory của session hiện tại và bị xóa khi session kết thúc, abort, module disable hoặc Mac sleep.

Nếu tương lai có lưu history:

```text
explicit opt-in
clear retention rules
delete capability
```

---

# 50. Reset Identity

Destructive action:

```text
Reset Xiaozhi Identity…
```

Confirmation:

```text
Reset Xiaozhi Identity?

This creates a new Xiaozhi client identity
and may require activation again.

[ Cancel ]

[ Reset Identity ]
```

Reset sẽ:

```text
delete Client ID
delete Xiaozhi credentials if tied to identity
clear activation state
disconnect session
generate new identity
```

---

# 51. Advanced Settings

Collapsed mặc định.

```text
ADVANCED

Bootstrap Server
https://api.tenclass.net/...

Protocol Version
Automatic

Connection Timeout
10 seconds

Developer Diagnostics           [ ]
```

Không cần expose:

```text
Opus bitrate
frame duration
sample rate
VBR
DTX
FEC
binary packet format
queue length
MCP protocol version
```

---

# 52. Developer Diagnostics

Khi bật:

```text
Transport              WebSocket
Protocol               V1

Input                   Opus 16kHz Mono
Frame                   60 ms

Server Output           24 kHz

Session                 A91C••••

WebSocket               Connected

Uplink Queue            2
Downlink Queue          0

Dropped Uplink          0
Dropped Downlink        0
```

Phần lớn read-only.

---

# 53. Diagnostics Entry

Settings module chỉ hiển thị summary:

```text
DIAGNOSTICS

Connection             Connected

Handshake              82 ms

Audio Input            Active

Audio Output           Active

Dropped Frames         0

Last Error             None

[ Open Xiaozhi Diagnostics ]
```

Chi tiết nằm trong:

```text
Settings
→ Diagnostics
→ Xiaozhi
```

---

# 54. Diagnostics detailed view

Có thể gồm:

```text
Bootstrap Status
Activation Status
WebSocket State
Handshake Latency
Protocol Version
Negotiated Audio
Reconnect Count
Uplink Queue
Downlink Queue
Dropped Packets
Encode Errors
Decode Errors
Playback Underruns
WebSocket Close Code
Last Protocol Error
```

Không hiển thị token.

---

# 55. Settings ownership

Phân chia rõ:

```text
GLOBAL NOTCHHUB SETTINGS
├── Permissions
├── Diagnostics
├── Appearance
└── Notch global behavior


XIAOZHI SETTINGS
├── Enabled
├── Connection
├── Activation
├── Conversation Mode
├── Audio Device
├── Voice Behavior
├── Notch Xiaozhi presentation
└── Privacy


INTERNAL XIAOZHI CONFIG
├── Token
├── Session ID
├── Opus parameters
├── Binary framing
├── MCP internals
└── Buffer configuration
```

Xiaozhi Module sở hữu schema, validation và Settings application-scene UI của nhóm `XIAOZHI SETTINGS`. Phần non-secret được Settings store persist trong snapshot versioned theo ModuleID; module không tạo file settings hoặc `UserDefaults` riêng.

---

# 56. Những setting không nên expose

Không đưa vào normal Settings:

```text
Opus Bitrate
Opus VBR
Opus DTX
Opus FEC
16 kHz Sample Rate
60 ms Frame
WebSocket Binary V1/V2/V3
MCP Version
Session ID
Bearer Token
AEC Timestamp
Queue Size
Raw JSON
```

Những thứ này thuộc implementation/diagnostics.

---

# 57. Recommended final Settings layout

```text
Xiaozhi
─────────────────────────────────

● Connected
Native Xiaozhi Client

Enabled                         [✓]


GENERAL

Start on Launch                 [✓]

Auto Reconnect                  [✓]

Conversation Mode               Auto >


VOICE

Microphone
MacBook Microphone              >

Interrupt Response              [✓]

Continue Conversation           [✓]


AUDIO

Output
MacBook Speakers                >

Show Transcript When Muted      [✓]


NOTCH BEHAVIOR

Listening Display
Voice Activity                  >

Speaking Display
Voice Activity                  >

When Muted
Scrolling Text                  >

Show User Transcript            [ ]

Show Xiaozhi Text               [✓]


CONNECTION

Activation
Activated

Client ID
7A39••••B21C

Server
Xiaozhi Cloud

[ Reconnect ]


PERMISSIONS

Microphone
Allowed                         >


PRIVACY

Store Transcript                [ ]


ADVANCED                        >


DIAGNOSTICS                     >


Reset Xiaozhi Identity…
```

---

# 58. Editable settings count

Phiên bản đầu không nên có quá nhiều preference.

Target:

```text
~12–15 user-editable settings
```

Phần còn lại là:

```text
status
read-only diagnostics
advanced information
```

Mục tiêu là:

```text
powerful enough
but not a protocol control panel
```

---

# 59. Notch state mapping

```text
Idle
→ no Xiaozhi surface

Connecting
→ subtle status

Listening
→ voice activity

Thinking
→ processing indicator

Speaking
→ voice activity

Muted + Speaking
→ single-line transcript ticker

Error
→ compact error state
```

---

# 60. Transcript rules

Assistant text lấy từ:

```text
tts.sentence_start.text
```

User text lấy từ:

```text
stt.text
```

Notch ưu tiên assistant transcript.

Không hiển thị cả user và assistant cùng lúc trong compact layout.

Transcript ticker:

```text
single line
continuous
no wrapping
camera-safe
bounded length
```

Long transcript:

```text
not retained after the active session
```

---

# 61. Privacy & Security Requirements

Remote Xiaozhi data được coi là untrusted.

Bắt buộc:

```text
bounded JSON
bounded binary frame
strict protocol parsing
bounded queues
TLS/WSS
Keychain secrets
redacted diagnostics
Action allow-list
no arbitrary execution
```

Không log:

```text
Authorization
Token
Activation Secret
Raw Keychain values
Continuous Microphone Audio
```

Transcript logging mặc định:

```text
Off
```

---

# 62. Actions

Module có thể register:

```text
xiaozhi.start
xiaozhi.stop
xiaozhi.abort
xiaozhi.reconnect
xiaozhi.pushToTalk
xiaozhi.resetIdentity
```

`resetIdentity` cần confirmation.

---

# 63. Implementation phases

## NX0 — Domain / Protocol Fixtures

```text
Message models
State reducer
Hello
STT
TTS
Binary V1
Tests
```

## NX1 — Identity & Bootstrap

```text
Client ID
Device ID
Bootstrap
Activation parsing
Token storage
```

## NX2 — WebSocket

```text
Headers
Connect
Client Hello
Server Hello
Session ID
Receive loop
Disconnect
```

## NX3 — TTS Playback

```text
Binary receive
Opus decode
Resample
Playback
TTS states
```

## NX4 — Microphone

```text
Permission
Capture
16kHz resample
Opus encode
Send audio
Listen start/stop
```

## NX5 — Conversation

```text
Auto Mode
Push-to-Talk
Abort
Playback Drain
Reconnect
```

## NX6 — Settings

```text
Module page
Voice settings
Connection state
Notch behavior
Privacy
Diagnostics summary
```

## NX7 — MCP (Future)

```text
initialize
tools/list
tools/call
NotchActions mapping
```

## NX8 — Advanced Audio

```text
AEC
Realtime mode
Protocol V2
Audio route changes
```

## NX9 — Hardening

```text
Sleep/Wake
Network transitions
Malformed protocol data
Long sessions
Permission denial
Audio-device switching
Performance profiling
```

---

# 64. Test requirements

## Unit tests

```text
Identity persistence
Bootstrap headers
Bootstrap decoding
Activation
Client Hello
Server Hello
Session ID
Listening commands
Abort
STT
TTS
LLM
MCP (deferred)
Binary V1
Binary V2
Binary V3
State transitions
Queue bounds
Secret redaction
Settings validation
```

## Fake Server tests

Local deterministic WebSocket server:

```text
inspect headers
receive client hello
send server hello
send STT
send TTS
send Opus
delay hello
disconnect
send malformed frame
MCP test scenarios (future phase only)
```

## Real Xiaozhi backend tests

```text
Bootstrap accepted
Device ID accepted
Client ID accepted
Activation
WebSocket auth
Hello
Manual mode
Auto mode
Microphone audio
STT
TTS text
TTS audio
Abort
Reconnect
Sleep/Wake
```

---

# 65. Open compatibility questions

Cần xác minh bằng real backend:

```text
1. Device-Id format cho macOS?

2. Bootstrap fields tối thiểu?

3. Desktop activation flow?

4. Protocol versions backend hỗ trợ?

5. MCP có bắt buộc không?

6. Token lifetime?

7. Bootstrap refresh timing?

8. Server-side AEC requirements?

9. Realtime mode expectations?
```

Không hardcode câu trả lời trước khi integration test xác nhận.

---

# 66. Required documentation changes in NotchHub

Kiến trúc hiện tại của NotchHub trước đây đặt:

```text
M1
Xiaozhi Display Companion

M5
Native Xiaozhi Voice
```

Mục tiêu mới thay đổi assumption này.

Nên tạo ADR:

```text
docs/architecture/decisions/
0018-native-xiaozhi-client-direct-connection.md
```

Decision:

```text
NotchHub implements Xiaozhi as a native macOS client
with direct bootstrap, authenticated WebSocket,
microphone streaming, TTS playback, transcript,
and controlled MCP integration.
```

Các tài liệu cần cập nhật:

```text
README.md

docs/product/
├── vision.md
├── roadmap.md
└── requirements.md

docs/architecture/
├── overview.md
├── c4-context.md
├── c4-container.md
├── module-system.md
└── performance.md

docs/platform/
└── permissions.md

docs/security/
└── threat-model.md

docs/quality/
└── testing-strategy.md

docs/index.md
```

---

# 67. Definition of Done

Native Xiaozhi Client MVP hoàn thành khi flow sau hoạt động ổn định:

```text
Launch NotchHub
      ↓
Load Xiaozhi Identity
      ↓
Bootstrap
      ↓
Activate if required
      ↓
User starts Xiaozhi
      ↓
WebSocket
      ↓
Client Hello
      ↓
Server Hello
      ↓
Session ID
      ↓
Listen Start
      ↓
Microphone
      ↓
16 kHz Mono PCM
      ↓
Opus
      ↓
Xiaozhi Backend
      ↓
STT
      ↓
TTS Start
      ↓
Transcript + Opus Audio
      ↓
Notch + Mac Speaker
      ↓
TTS Stop
      ↓
Playback Drain
      ↓
Listening Again
```

Và đồng thời đảm bảo:

```text
No unbounded audio buffer

No secret leakage

No microphone without user intent

No arbitrary remote execution

Clean reconnect

Clean sleep/wake

Clean module shutdown

Safe settings reset

Camera-safe Notch UI
```

---

# 68. Final architecture rule

Luồng cuối cùng phải giữ boundary:

```text
Xiaozhi Network
       ↓
Xiaozhi Transport
       ↓
Xiaozhi Session Controller
       ↓
Xiaozhi Store
       ↓
Normalized Module State
       ↓
Notch Surface
```

Không để:

```text
NotchSurface
```

biết chi tiết Xiaozhi protocol.

Không để:

```text
XiaozhiTransport
```

biết:

```text
NSPanel
Notch geometry
SwiftUI animation
hover
expanded/collapsed state
```

Đây là boundary quan trọng nhất để module Native Xiaozhi có thể phát triển lâu dài mà không làm kiến trúc NotchHub bị phụ thuộc vào một integration cụ thể.
