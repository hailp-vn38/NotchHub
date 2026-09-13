# macOS Notch Platform Modular
## Tài liệu kiến trúc và lộ trình xây dựng base project

> **Deprecated — historical draft only.** This document contains an earlier product scope that included ESP-IDF, ESP32 Gateway, IoT, and developer tooling. Those areas are permanently excluded from NotchHub. Do not use this file as an implementation source. The authoritative documents are [`vision.md`](../product/vision.md), [`requirements.md`](../product/requirements.md), [`roadmap.md`](../product/roadmap.md), and [`architecture/overview.md`](../architecture/overview.md).

**Archived:** 2026-09-13  
**Superseded by:** `docs/product/vision.md`, `docs/product/requirements.md`, `docs/product/roadmap.md`

**Tên làm việc:** NotchHub (có thể đổi thành NotchOS, NotchBridge, DevNotch hoặc XiaozhiNotch sau này)  
**Nền tảng:** macOS 14 Sonoma trở lên  
**Ngôn ngữ:** Swift 6  
**UI:** SwiftUI + AppKit  
**Mục tiêu:** Xây dựng một nền tảng notch modular, ổn định và mở rộng được. Xiaozhi Voice AI là một module quan trọng đầu tiên, nhưng không phải core của sản phẩm.

---

## 1. Tóm tắt quyết định kiến trúc

Base project được định nghĩa là một **macOS Notch Platform modular**:

- Một interaction surface quanh notch của MacBook để hiển thị trạng thái ngắn, chạy action nhanh và mở các tương tác tức thời.
- Core xử lý panel/window, input, state machine, lifecycle, IPC, bảo mật, settings và module runtime.
- Mỗi chức năng như Xiaozhi, media, clipboard, file shelf, system metrics, calendar, ESP-IDF, Git hoặc ESP32 gateway là một module độc lập.
- UI Notch không phụ thuộc trực tiếp vào giao thức Xiaozhi, WebSocket, ESP-IDF, shell command hay bất kỳ backend cụ thể nào.
- Mọi event bên ngoài đều được chuẩn hóa qua event contract có version.
- Mọi command từ AI, voice hoặc mạng đều phải được map vào action đã đăng ký, có allow-list và validation. Không cho AI chạy shell command tùy ý.

### Nguyên tắc cốt lõi

1. **Notch là glance + quick action**, không phải màn hình dashboard đầy đủ.
2. **Core ổn định, module thay đổi được.**
3. **Một owner duy nhất cho notch window.**
4. **Event-driven, không để module gọi trực tiếp lẫn nhau.**
5. **Permission theo nhu cầu của module, không xin toàn bộ khi app mở lần đầu.**
6. **Security-by-default cho IPC, token, action execution và AI integration.**
7. **Bắt đầu với built-in display và public macOS APIs; mở rộng sau khi hệ thống ổn định.**

---

## 2. Boring Notch: nguồn tham khảo, không phải base để fork nguyên khối

[Boring Notch](https://github.com/TheBoredTeam/boring.notch) là dự án open-source quan trọng để nghiên cứu cách một ứng dụng macOS biến vùng notch thành interface tương tác. Nó là một app Swift/SwiftUI, hỗ trợ nhiều tính năng như media control, calendar, file shelf, AirDrop, system HUD và quản lý cửa sổ Notch.

### Nên tham khảo từ Boring Notch

- Cách tạo và quản lý `NSPanel` / window nổi quanh notch.
- Cách phối hợp SwiftUI với AppKit cho các hành vi windowing phức tạp.
- Layout logic cho notch thật và màn hình không có notch.
- Animation mở/đóng, hover interaction, state/view coordination.
- Tổ chức feature manager, settings, persistence và permission flow.
- Xử lý lifecycle: launch, sleep/wake, màn hình thay đổi, full-screen, đổi Space.
- Xây dựng, signing, packaging và CI/CD khi đến giai đoạn phát hành.

### Không nên làm

- Không fork nguyên codebase rồi thêm tất cả feature mới vào cùng một app target.
- Không copy code mà không đọc license, dependency license và rationale kỹ thuật.
- Không gắn Xiaozhi/WebSocket/ESP-IDF trực tiếp vào layer UI/window.
- Không mang toàn bộ file shelf, AirDrop, camera, calendar, system HUD vào bản đầu.
- Không phụ thuộc private API nếu chưa thật sự bắt buộc.

### Cách dùng Boring Notch đúng

1. Khởi tạo project sạch, nhỏ và có module boundaries rõ.
2. Chọn từng vấn đề cụ thể: ví dụ hover overlay, click-through, panel level, full-screen behavior.
3. Đọc implementation Boring Notch để học pattern và edge case.
4. Viết implementation mới phù hợp với kiến trúc của NotchHub.
5. Ghi lại source tham khảo trong `Docs/references.md` và kiểm tra nghĩa vụ license trước khi tái sử dụng code.

Boring Notch là **reference implementation**, không phải kiến trúc plugin platform hoàn chỉnh dành riêng cho dự án này.

---

## 3. Phạm vi sản phẩm

### 3.1. Bốn lớp trải nghiệm

| Lớp | Mục tiêu | Ví dụ |
|---|---|---|
| Passive indicator | Nhìn lướt, gần như không chiếm không gian | Xiaozhi online/offline, media playing, build đang chạy |
| Compact notch | Một đến vài dòng trạng thái, tự đóng | “Xiaozhi đang suy nghĩ…”, “Build thành công · 18.4 s” |
| Expanded panel | Tương tác nhanh trong vài giây | Push-to-talk, media controls, action grid, clipboard, device status |
| Detail window | Nội dung dài và cấu hình | Full transcript, build log, gateway dashboard, settings |

### 3.2. Chức năng theo nhóm

| Nhóm | Chức năng mẫu |
|---|---|
| AI / Xiaozhi | Voice state, transcript streaming, push-to-talk, stop, mute, tool progress, full transcript |
| Media | Now playing, play/pause, next/previous, output device |
| System | Volume, brightness, battery, Wi-Fi, Bluetooth, CPU/RAM/network summary |
| Productivity | Clipboard history, timer, calendar, reminders, quick notes |
| Files | Drag/drop shelf, file actions, recent file transfer |
| Developer | ESP-IDF build/flash/monitor, serial selector, Git state, local services |
| IoT/Gateway | ESP BLE gateway status, device count, OTA progress, local dashboard, quick commands |
| Platform | Module registry, IPC, settings, permissions, logging, diagnostics, updater strategy |

### 3.3. Những giới hạn UX bắt buộc

- Transcript dài không hiển thị toàn bộ trong notch.
- Build log hoặc serial log không stream vô hạn vào SwiftUI view trên notch.
- Expanded panel tự thu gọn khi timeout hoặc người dùng click ra ngoài.
- Không tự expand che màn hình chỉ vì một event không quan trọng.
- Khi screen sharing hoặc full-screen, áp dụng policy tối giản hoặc auto-hide tùy user setting.

---

## 4. Technology stack

| Thành phần | Lựa chọn | Lý do |
|---|---|---|
| Minimum deployment target | macOS 14 Sonoma | Dùng được Observation, Swift Concurrency và giảm gánh nặng compatibility |
| Ngôn ngữ | Swift 6 | Actor, `async/await`, `AsyncStream`, strict concurrency |
| UI | SwiftUI | Layout, animation, settings và reusable view components |
| Windowing | AppKit | `NSPanel`, `NSScreen`, `NSEvent`, window level, Spaces/full-screen integration |
| App entry | `MenuBarExtra` + `AppDelegate` | Menu bar là recovery/control path đáng tin cậy khi notch panel đang bị ẩn hoặc lỗi |
| State observation | Observation `@Observable` | State-driven UI, phù hợp macOS 14+ |
| Concurrency | Actors + task groups + `AsyncStream` | Tách I/O, WebSocket, process execution khỏi main actor |
| Persistence | `UserDefaults` + Codable | User preferences và workspace profiles không nhạy cảm |
| Secrets | Keychain | API token, local IPC secret, Xiaozhi credential |
| Networking/IPC | Unix domain socket trước; HTTP/WebSocket sau | Secure local IPC trước, dễ thêm integration và relay sau |
| Logging | `os.Logger` + file ring buffer | Debug theo category, privacy-aware, diagnostics export |
| Dependency manager | Swift Package Manager | Module hóa rõ, CI sạch, ít phụ thuộc |
| Tests | Swift Testing + XCTest | Test pure domain/core, integration test IPC, UI smoke test |

### Chỉ dùng public API ở phiên bản đầu

Ưu tiên các framework công khai:

- SwiftUI
- AppKit
- Foundation
- Observation
- Network
- AVFoundation
- EventKit
- UserNotifications
- Security / Keychain
- OSLog

Không dùng private frameworks hoặc API không tài liệu hóa chỉ để có hiệu ứng notch đẹp hơn. Nếu sau này một system feature buộc phải có quyền cao hơn, tách nó thành adapter hoặc helper riêng để core không bị khóa vào implementation đó.

---

## 5. Kiến trúc tổng thể

### 5.1. Sơ đồ lớp

```text
┌────────────────────────────────────────────────────────────┐
│ Apps                                                        │
│  NotchHubApp · AppDelegate · Menu Bar · Settings            │
└───────────────────────────┬────────────────────────────────┘
                            │ composition root
┌───────────────────────────▼────────────────────────────────┐
│ Modules                                                     │
│ Xiaozhi · Media · Clipboard · Files · System · Developer    │
│ Gateway · Calendar                                          │
└───────┬──────────────────────┬─────────────────────┬───────┘
        │                      │                     │
┌───────▼───────────┐ ┌────────▼───────────┐ ┌──────▼────────┐
│ NotchSurface      │ │ NotchActions       │ │ NotchIPC      │
│ NSPanel + UI      │ │ Registry/Executors │ │ Socket/WS/API │
└───────┬───────────┘ └────────┬───────────┘ └──────┬────────┘
        └──────────────────────┴─────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────────┐
│ NotchCore                                                   │
│ ModuleRuntime · EventBus · Policy · Permissions · Settings  │
│ Security · Diagnostics · Lifecycle                           │
└───────────────────────────┬────────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────────┐
│ NotchDomain                                                 │
│ Models · Events · Commands · Contracts · Errors              │
│ Pure Swift, không SwiftUI/AppKit                             │
└────────────────────────────────────────────────────────────┘
```

### 5.2. Hướng phụ thuộc

```text
Apps / Modules / Tools
         ↓
NotchSurface + NotchActions + NotchIPC + NotchUI
         ↓
      NotchCore
         ↓
     NotchDomain
```

Quy tắc:

- `NotchDomain` không import SwiftUI, AppKit hoặc networking implementation.
- `NotchCore` không biết chi tiết UI của từng module.
- `NotchSurface` không biết Xiaozhi, ESP-IDF, raw WebSocket protocol hay shell command.
- `Modules` không tạo/resize/show/hide `NSPanel` trực tiếp.
- Chỉ app composition root quyết định module nào được đăng ký khi launch.
- `Tools` nói chuyện với app qua IPC/event contract, không import App target.

### 5.3. Thành phần chính

| Thành phần | Trách nhiệm |
|---|---|
| `NotchDomain` | Model, protocol, event envelope, command, error, type-safe identifiers |
| `NotchCore` | Lifecycle, module runtime, event bus, app store, presentation policy, settings, permissions, security, diagnostics |
| `NotchSurface` | `NSPanel`, screen/notch geometry, hover, click-through, hotkey, state transitions, SwiftUI hosting |
| `NotchUI` | Design system, common components, typography, animations, widget containers |
| `NotchActions` | Action manifest, registry, authorization, executor, process lifecycle, result streaming |
| `NotchIPC` | Unix socket, HTTP/WebSocket local API, auth, decoding, rate-limit, event router |
| `Modules` | Business capability theo domain: Xiaozhi, Media, Clipboard, Developer, Gateway... |
| `Tools` | CLI `notchctl`, Xiaozhi relay, optional developer helper tools |

---

## 6. Cấu trúc repository đề xuất

```text
NotchHub/
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── SECURITY.md
├── Package.swift
├── NotchHub.xcodeproj/
│
├── Apps/
│   ├── NotchHubApp/
│   │   ├── NotchHubApp.swift
│   │   ├── AppDelegate.swift
│   │   ├── AppCoordinator.swift
│   │   ├── CompositionRoot.swift
│   │   ├── MenuBar/
│   │   ├── Settings/
│   │   └── Resources/
│   └── NotchHubPrivilegedHelper/       # chưa tạo ở P0 nếu không bắt buộc
│
├── Packages/
│   ├── NotchDomain/
│   │   ├── Sources/NotchDomain/
│   │   │   ├── Models/
│   │   │   ├── Events/
│   │   │   ├── Commands/
│   │   │   ├── Contracts/
│   │   │   └── Errors/
│   │   └── Tests/NotchDomainTests/
│   │
│   ├── NotchCore/
│   │   ├── Sources/NotchCore/
│   │   │   ├── AppStore/
│   │   │   ├── EventBus/
│   │   │   ├── ModuleRuntime/
│   │   │   ├── Presentation/
│   │   │   ├── Permissions/
│   │   │   ├── Persistence/
│   │   │   ├── Security/
│   │   │   ├── Diagnostics/
│   │   │   └── Lifecycle/
│   │   └── Tests/NotchCoreTests/
│   │
│   ├── NotchSurface/
│   │   ├── Sources/NotchSurface/
│   │   │   ├── Windowing/
│   │   │   │   ├── NotchPanelController.swift
│   │   │   │   ├── ScreenTopology.swift
│   │   │   │   ├── NotchGeometry.swift
│   │   │   │   ├── ScreenObserver.swift
│   │   │   │   └── SpaceFullscreenObserver.swift
│   │   │   ├── Interaction/
│   │   │   │   ├── InteractionStateMachine.swift
│   │   │   │   ├── PointerMonitor.swift
│   │   │   │   ├── ClickOutsideMonitor.swift
│   │   │   │   └── GlobalHotkeyService.swift
│   │   │   └── Views/
│   │   │       ├── NotchRootView.swift
│   │   │       ├── CollapsedNotchView.swift
│   │   │       ├── CompactStatusView.swift
│   │   │       ├── ExpandedNotchView.swift
│   │   │       └── DetailPopoverView.swift
│   │   └── Tests/NotchSurfaceTests/
│   │
│   ├── NotchUI/
│   │   ├── Sources/NotchUI/
│   │   │   ├── DesignSystem/
│   │   │   ├── Components/
│   │   │   ├── Animation/
│   │   │   └── Accessibility/
│   │   └── Tests/NotchUITests/
│   │
│   ├── NotchActions/
│   │   ├── Sources/NotchActions/
│   │   │   ├── ActionDefinition.swift
│   │   │   ├── ActionRegistry.swift
│   │   │   ├── ActionAuthorizer.swift
│   │   │   ├── ActionExecutor.swift
│   │   │   ├── ShellActionExecutor.swift
│   │   │   ├── URLActionExecutor.swift
│   │   │   ├── ShortcutActionExecutor.swift
│   │   │   └── ProcessOutputParser.swift
│   │   └── Tests/NotchActionsTests/
│   │
│   └── NotchIPC/
│       ├── Sources/NotchIPC/
│       │   ├── EventEnvelope.swift
│       │   ├── LocalSocketServer.swift
│       │   ├── LocalHTTPServer.swift
│       │   ├── LocalWebSocketServer.swift
│       │   ├── RequestAuthenticator.swift
│       │   ├── RateLimiter.swift
│       │   └── EventRouter.swift
│       └── Tests/NotchIPCTests/
│
├── Modules/
│   ├── Xiaozhi/
│   ├── Media/
│   ├── Clipboard/
│   ├── Files/
│   ├── SystemMetrics/
│   ├── Calendar/
│   ├── DeveloperTools/
│   └── Gateway/
│
├── Tools/
│   ├── notchctl/
│   └── xiaozhi-relay/
│
├── Tests/
│   ├── IntegrationTests/
│   ├── UIAutomationTests/
│   └── Fixtures/
│
├── Docs/
│   ├── architecture.md
│   ├── module-sdk.md
│   ├── event-protocol.md
│   ├── action-manifest.md
│   ├── ipc-security.md
│   ├── privacy-permissions.md
│   ├── testing.md
│   ├── release.md
│   ├── roadmap.md
│   └── references.md
│
└── .github/
    └── workflows/
        ├── ci.yml
        ├── lint.yml
        └── release.yml
```

---

## 7. Notch surface và windowing

### 7.1. Trách nhiệm của `NotchPanelController`

`NotchPanelController` là **owner duy nhất** của mọi thao tác liên quan `NSPanel`:

- Tạo và hủy panel.
- Gắn SwiftUI root view thông qua `NSHostingView` hoặc `NSHostingController`.
- Chọn màn hình target.
- Tính frame cho collapsed / compact / expanded / detail mode.
- Thiết lập window level, collection behavior và order front/out.
- Xử lý screen configuration change.
- Phối hợp với state machine để animate frame và opacity.
- Quản lý hit-testing/click-through theo trạng thái.

Module không được import controller này và không được gọi `show`, `hide`, `setFrame` trực tiếp.

### 7.2. State machine cho surface

```text
hidden
  → collapsed
  → compact
  → expanded
  → detail
  → collapsed

collapsed / compact / expanded / detail
  → suppressed
  → errorRecovery

suppressed
  → collapsed
```

Các trigger tiêu biểu:

| Trigger | Chuyển trạng thái |
|---|---|
| App launch | `hidden → collapsed` |
| Hover/click/hotkey | `collapsed → expanded` |
| Event cần thông báo ngắn | `collapsed → compact` |
| Click transcript hoặc widget detail | `compact/expanded → detail` |
| Escape/click ngoài/timeout | `expanded/detail → collapsed` |
| Full-screen/screen share policy | `* → suppressed` |
| Panel bị invalid/screen removed | `* → errorRecovery → collapsed` |

Tách surface state khỏi feature state:

```text
SurfaceState: hidden | collapsed | compact | expanded | detail | suppressed
AssistantState: disconnected | idle | listening | thinking | speaking | error
MediaState: idle | playing | paused
BuildState: idle | running | succeeded | failed
GatewayState: offline | connecting | online | degraded
```

Không được để `AssistantState.thinking` tự ý ép toàn bộ UI vào `expanded`; `PresentationPolicy` mới là nơi quyết định điều này.

### 7.3. Chính sách màn hình ở MVP

Bản P0/P1:

- Chỉ hỗ trợ built-in display của MacBook.
- Nếu không có built-in display/notch, đặt panel top-center theo safe/visible frame.
- Không render notch panel trên external display mặc định.
- Khi MacBook đóng nắp hoặc built-in display unavailable: hide panel an toàn, giữ menu bar app.

Bản P3 mới cân nhắc multi-display policy do user cấu hình.

### 7.4. Input và click-through

- Khi collapsed: vùng tương tác tối thiểu, không vô tình chặn menu bar hoặc click của app khác.
- Khi expanded: panel nhận hover, click và drag/drop theo feature được bật.
- Click outside / Escape phải thu panel một cách nhất quán.
- Hotkey cần abstraction riêng; nếu cần permission Accessibility, request theo feature.
- Không xử lý event global liên tục nếu không cần, vì có rủi ro privacy/performance.

---

## 8. Module SDK

### 8.1. Static module trước, dynamic plugin sau

Trong giai đoạn đầu, “plugin” nghĩa là module được compile cùng app, đăng ký qua protocol. Không nạp runtime `.dylib`, `.bundle` hay script không đáng tin cậy.

Lý do:

- Dễ build, test, signing và notarization.
- Tránh rủi ro chạy code tùy ý.
- Tránh phức tạp ABI/versioning khi module API còn thay đổi.
- Vẫn đủ modular để tách package, owner và lifecycle.

Khi module contract đã ổn định, mới đánh giá external plugin bundle hoặc marketplace.

### 8.2. Contract đề xuất

```swift
public protocol NotchModule: Sendable {
    var id: ModuleID { get }
    var metadata: ModuleMetadata { get }

    func start(context: ModuleContext) async throws
    func stop() async

    func handle(_ command: ModuleCommand) async throws -> ModuleCommandResult
}
```

```swift
public struct ModuleMetadata: Codable, Sendable {
    public let displayName: String
    public let iconName: String
    public let supportedSurfaces: Set<SurfaceSlot>
    public let requiredPermissions: Set<PermissionKind>
    public let settingsRoute: SettingsRoute?
    public let priority: Int
}
```

```swift
public enum SurfaceSlot: String, Codable, Sendable {
    case indicator
    case compactStatus
    case expandedPrimary
    case expandedSecondary
    case detail
    case menuBar
}
```

`ModuleContext` nên chỉ cung cấp capability có kiểm soát:

```swift
public struct ModuleContext: Sendable {
    public let eventBus: EventBus
    public let actionRegistry: ActionRegistry
    public let settings: ModuleSettingsStore
    public let permissions: PermissionCoordinator
    public let diagnostics: DiagnosticsReporter
}
```

Không truyền `NSPanel`, raw `NSApplication`, filesystem unrestricted hoặc `Process` executor thẳng vào module context.

### 8.3. Module lifecycle

```text
registered
  → starting
  → running
  → suspended
  → stopping
  → stopped
  → failed
```

Quy tắc runtime:

- Module fail không được kéo crash toàn app.
- `start` idempotent hoặc module runtime phải bảo đảm không gọi song song.
- `stop` cancel task, disconnect socket, flush state cần thiết.
- Runtime ghi metrics start latency, restart count, last error.
- User có thể disable module mà không cần restart app nếu module hỗ trợ hot stop/start.

---

## 9. Event bus và event contract

### 9.1. Vì sao cần event contract

Notch UI sẽ nhận event từ nhiều nguồn:

- Xiaozhi relay.
- Local CLI/script.
- ESP-IDF build runner.
- ESP BLE gateway.
- Media observer.
- Clipboard watcher.
- System metrics service.

Không để mỗi nguồn update SwiftUI view trực tiếp. Tất cả phải được parse, validate, version hóa và gửi vào `EventBus`.

### 9.2. Envelope chuẩn

```swift
public struct EventEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public let id: UUID
    public let version: Int
    public let source: String
    public let type: String
    public let timestamp: Date
    public let correlationID: UUID?
    public let payload: Payload
}
```

Khi cần heterogeneous event payload, dùng enum type-safe nội bộ sau khi decode envelope JSON ngoài:

```swift
public enum AppEvent: Sendable {
    case assistant(AssistantEvent)
    case tool(ToolEvent)
    case developer(DeveloperEvent)
    case gateway(GatewayEvent)
    case media(MediaEvent)
    case system(SystemEvent)
    case action(ActionEvent)
}
```

### 9.3. Nhóm event

```text
app.lifecycle.*
surface.state.*
module.status.*
assistant.*
media.*
clipboard.*
files.*
system.*
developer.*
gateway.*
action.*
notification.*
```

### 9.4. Event Xiaozhi mẫu

```json
{
  "id": "f3c61e35-245a-4c7d-8f9f-a967a1e52bd4",
  "version": 1,
  "source": "xiaozhi.relay",
  "type": "assistant.transcript.delta",
  "timestamp": "2026-09-12T15:45:00Z",
  "correlationID": "27b581d6-8af4-4c65-a450-dcbca40bb26c",
  "payload": {
    "sessionID": "27b581d6-8af4-4c65-a450-dcbca40bb26c",
    "role": "assistant",
    "text": "Gateway BLE hiện đang có bốn thiết bị",
    "sequence": 31,
    "isFinal": false
  }
}
```

### 9.5. Event rules

- Có `version` từ v1 ngay ngày đầu.
- Có `id` để trace và deduplicate.
- Có `source` để audit/debug.
- Có `correlationID` để liên kết voice session, tool action, process run.
- Có `sequence` với transcript delta/tool progress để bỏ qua message đến trễ.
- Validate schema và giới hạn payload size trước khi đưa vào app store.
- Rate-limit event và có backpressure policy.
- Không publish raw token, password, authorization header, full shell environment hay private transcript ra log mặc định.

---

## 10. Action platform và security boundary

### 10.1. Nguyên tắc action

AI/voice/IPC **không được chạy raw shell command**. External input chỉ có thể gọi một action đã được app đăng ký.

```text
Voice / Xiaozhi / IPC request
           ↓
Action ID + validated input
           ↓
ActionRegistry
           ↓
Authorization + policy check
           ↓
Typed ActionExecutor
           ↓
Result/progress event
```

### 10.2. Action definition

```swift
public struct ActionDefinition: Codable, Sendable, Identifiable {
    public let id: ActionID
    public let title: String
    public let iconName: String
    public let category: ActionCategory
    public let inputSchema: ActionInputSchema
    public let confirmationPolicy: ConfirmationPolicy
    public let executorKind: ExecutorKind
    public let timeout: Duration
}
```

Manifest ví dụ cho ESP-IDF:

```json
{
  "id": "developer.idf.flash",
  "title": "Flash ESP32",
  "icon": "bolt.horizontal.circle",
  "category": "Developer",
  "executor": {
    "kind": "shell",
    "command": "idf.py flash",
    "workingDirectory": "~/workspace/esp-ble-gateway",
    "timeoutSeconds": 180
  },
  "requiresConfirmation": true
}
```

### 10.3. Executor types

| Executor | Ví dụ | Ghi chú |
|---|---|---|
| URL | Mở dashboard, GitHub repo, Settings | Validate URL scheme/host nếu cần |
| App launch | Mở Terminal, iTerm, VS Code | Allow-list app bundle ID |
| Shell profile | `idf.py build`, `idf.py flash` | Chỉ command profile đã lưu/được xác nhận |
| AppleScript | Automation có kiểm soát | Tách permission và sanitize input |
| HTTP local/LAN | Gọi gateway API | Token, host allow-list, timeout |
| Module command | Xiaozhi stop/mute, media pause | Type-safe command, không shell |

### 10.4. Chính sách confirmation

- Action read-only: có thể chạy ngay, ví dụ refresh gateway status.
- Action thay đổi cục bộ: có thể cho user bật “always allow” riêng action đó, ví dụ open workspace.
- Action destructive/hardware: luôn confirm, ví dụ flash firmware, OTA, reboot device, erase flash.
- AI-triggered action: mặc định confirm nếu action có side effect; UI phải hiển thị action title, target, input và source.

---

## 11. Local IPC và API

### 11.1. Mục tiêu

Cho phép script, Xiaozhi relay, build process và gateway companion gửi event vào app mà không buộc toàn bộ logic nằm trong UI process.

### 11.2. Thứ tự triển khai

1. **Unix domain socket** cho `notchctl` và local tools.
2. **HTTP loopback** cho integration dễ viết bằng Python/Node/bash.
3. **WebSocket loopback** cho streaming transcript/status realtime.
4. LAN API chỉ thêm khi có security model rõ ràng.

### 11.3. Endpoint gợi ý

```text
GET  /v1/health
GET  /v1/status
POST /v1/events
POST /v1/actions/{actionID}
GET  /v1/sessions/{sessionID}
WS   /v1/stream
```

### 11.4. Security baseline

- Bind vào `127.0.0.1` hoặc Unix socket; không bind `0.0.0.0` ở bản đầu.
- Sinh random token; lưu Keychain hoặc một local protected file với permission phù hợp.
- Token qua `Authorization: Bearer ...` hoặc WebSocket initial auth message.
- Reject payload quá lớn, event type không hợp lệ, version không hỗ trợ.
- Rate-limit theo client/process.
- Log audit: source, event type, action ID, result; redaction secrets.
- Nếu nhận event từ LAN trong tương lai: TLS hoặc HMAC chữ ký + nonce/timestamp + replay protection.

### 11.5. `notchctl` CLI mẫu

```bash
notchctl status
notchctl emit assistant.state --state thinking
notchctl emit developer.build.started --project esp-ble-gateway
notchctl action developer.idf.build
notchctl action xiaozhi.push-to-talk
```

CLI không cần biết UI; nó chỉ gửi contract chuẩn vào IPC.

---

## 12. Xiaozhi module

### 12.1. Vai trò

Xiaozhi là module voice/AI:

- Hiển thị trạng thái: disconnected, idle, listening, thinking, speaking, error.
- Stream user transcript và assistant transcript.
- Hiển thị tool started/progress/completed/failed.
- Cung cấp action: push-to-talk, stop, mute, reconnect, open conversation.
- Làm cầu nối UX cho MCP/tool invocation của hệ IoT và developer workflows.

### 12.2. Không coupling trực tiếp với raw protocol

Xiaozhi ESP32/server có thể dùng WebSocket song công, JSON control message, binary Opus frame, và MCP/JSON-RPC cho tool interaction. UI Notch không nên parse raw protocol này.

Dùng adapter:

```text
Xiaozhi ESP32 / Xiaozhi server
            ↓ raw protocol
xiaozhi-relay hoặc XiaozhiBridgeAdapter
            ↓ normalized EventEnvelope v1
NotchHub EventBus
            ↓
XiaozhiModule + NotchSurface
```

### 12.3. Event bắt buộc ở Xiaozhi v1

```text
session.started
assistant.state
user.transcript.delta
user.transcript.final
assistant.transcript.delta
assistant.transcript.final
assistant.audio.level
tool.started
tool.progress
tool.completed
tool.failed
session.ended
```

### 12.4. Transcript assembler

- Nhận delta, kiểm tra `sessionID` và `sequence`.
- Bỏ qua duplicate/out-of-order delta.
- Buffer text, flush UI ở nhịp khoảng 20–30 FPS thay vì render mỗi token.
- Tách Unicode theo grapheme cluster để tiếng Việt có dấu không bị hiển thị lỗi.
- Khi final: commit message vào session store.
- Giới hạn transcript in-memory; full history cần persistence do user bật rõ ràng.

### 12.5. Voice UX

```text
Idle        : notch tự nhiên hoặc indicator nhỏ
Listening   : badge mic + waveform + partial user text
Thinking    : trạng thái ngắn, animation nhẹ
Speaking    : stream assistant text + waveform/TTS indicator
Tool run    : title + progress gọn
Error       : icon lỗi + nút reconnect/detail
```

Không cần mic permission nếu Mac app chỉ hiển thị event từ Xiaozhi ESP32. Chỉ yêu cầu Microphone permission khi thêm chế độ “Use Mac microphone” ở phase sau.

---

## 13. Các module ưu tiên

### 13.1. P0: Foundation

| Module/capability | Mục tiêu |
|---|---|
| NotchSurface | Collapsed, compact, expanded, detail; built-in display |
| Menu bar | Open Settings, toggle Notch, diagnostics, quit |
| ModuleRuntime | Register/start/stop/error isolation |
| EventBus | Typed internal event + validated external envelope |
| ActionRegistry | Action IDs, validation, executor abstraction |
| IPC | Unix socket hoặc loopback HTTP tối thiểu |
| Settings | Global/module settings, migration version |
| Diagnostics | OSLog categories, ring buffer, debug panel |
| Tests | State machine, event parsing, action validation |

### 13.2. P1: Daily value

| Module | MVP |
|---|---|
| Xiaozhi | State + transcript via relay + stop/mute/reconnect |
| Media | Now playing, play/pause, next/previous |
| Clipboard | Recent text snippets, pin/copy/delete |
| Files | Drag/drop shelf cơ bản, open/reveal action |
| System controls | Volume, brightness, output selector nếu public API/permission phù hợp |
| Notifications | Error/action result/toast policy |

Chỉ chọn 2–3 utility module đầu tiên cùng Xiaozhi; không phát triển toàn bộ song song.

### 13.3. P2: Developer và gateway

| Module | MVP |
|---|---|
| DeveloperTools | Workspace profiles, build/flash/monitor action, status và last result |
| Serial | Port selector, connected/disconnected status, open terminal action |
| Git | Branch, dirty state, open repo/PR/CI link |
| Gateway | Online/offline, BLE device count, last error, OTA progress, dashboard link |
| Local events | Script/CI/gateway gửi status chuẩn vào app |

### 13.4. P3: Advanced

- Multi-display configurable.
- Calendar/reminders.
- Advanced file shelf.
- Focus/meeting mode.
- Screenshot/OCR/screen context.
- Native Mac microphone/audio client cho Xiaozhi.
- AI action planner với explicit approval UI.
- External plugin bundles sau khi module SDK ổn định.

---

## 14. Permission architecture

### 14.1. Permission matrix

| Permission | Module | Chỉ xin khi |
|---|---|---|
| Accessibility | Global hotkey, một số media/automation | User bật feature cần nó |
| Microphone | Native Xiaozhi Voice trên Mac | User bấm “Use Mac microphone” |
| Notifications | Alert background/action errors | User bật notification |
| Calendar | Calendar module | User mở/bật Calendar |
| Reminders | Reminders module | User mở/bật Reminders |
| Camera | Camera mirror | User bật camera preview |
| Screen Recording | Screenshot/OCR/context | User gọi feature tương ứng |
| Automation | AppleScript/other app control | Ngay trước action cần automation |

### 14.2. Permission coordinator

`PermissionCoordinator` cần:

- Check current status.
- Pre-permission explanation screen trong app.
- Request system permission đúng lúc.
- Emit result event.
- Hiển thị hướng dẫn mở System Settings khi request bị deny.
- Cho module biết capability available/unavailable mà không tự popup.

Không request hàng loạt khi launch. Điều đó làm giảm trust và dễ khiến user deny toàn bộ.

---

## 15. Concurrency, performance và độ ổn định

### 15.1. Actor boundaries

| Thành phần | Concurrency model |
|---|---|
| SwiftUI/AppStore presentation | `@MainActor` |
| EventBus | `actor` |
| ModuleRuntime | `actor` |
| Local IPC server | `actor` hoặc serial executor |
| WebSocket/Xiaozhi relay | `actor` |
| Action/process runner | `actor`, stream stdout/stderr |
| TranscriptAssembler | `actor` |
| Settings persistence | `actor` hoặc serial queue abstraction |
| OSLog | thread-safe call sites |

Không chạy WebSocket I/O, audio decode, polling, file scan hoặc `Process` blocking trên main actor.

### 15.2. Event pressure policy

- Bounded buffer cho transcript/log stream.
- Coalesce high-frequency state: audio level, CPU, network, progress.
- Flush visual updates theo frame cadence; không redraw mỗi byte/token.
- Giới hạn log line và output memory per running process.
- Drop policy có metrics/diagnostics để biết data bị drop.

### 15.3. Resilience

- Module reconnect với exponential backoff và giới hạn retry.
- Panel recreate khi screen config đổi hoặc native panel invalid.
- Persist tối thiểu để restart không mất profile/settings.
- Không persist secret hoặc raw transcript mặc định.
- Crash-safe writes: atomic file write nếu dùng file persistence ngoài UserDefaults.
- Tách helper process khỏi app UI nếu tác vụ privileged/unstable thật sự cần.

---

## 16. Testing strategy

### 16.1. Unit tests bắt buộc

| Khu vực | Case cần test |
|---|---|
| Interaction state machine | Hover, timeout, Escape, click outside, suppressed, recovery |
| Presentation policy | Event Xiaozhi/build/tool không làm UI expand sai ngữ cảnh |
| Event decoder | Version, missing field, invalid payload, oversized payload |
| Event ordering | Duplicate, out-of-order sequence, stale correlation ID |
| Transcript assembler | Delta, final, Unicode tiếng Việt, buffering, session reset |
| Action registry | Unknown action, invalid input, confirmation policy, allow-list |
| Shell executor | Timeout, cancellation, exit code, stdout/stderr limit |
| Permission coordinator | Denied/restricted/granted/notDetermined |
| Module runtime | Start fail, stop, restart, isolation module lỗi |
| IPC auth | Missing token, invalid token, rate-limit, loopback-only policy |

### 16.2. Integration tests

- `notchctl` gửi event → EventRouter → EventBus → AppStore state.
- Xiaozhi relay fixture stream → transcript UI state.
- Action event → confirmation → executor → result event.
- App restart → restore enabled modules/settings/workspace profile.
- Gateway mock → device status/OTA progress rendering.

### 16.3. Manual QA checklist

- Launch/relaunch app.
- Sleep/wake Mac.
- Lock/unlock.
- Chuyển Space.
- App khác full-screen.
- Menu bar auto-hide.
- Cắm/rút màn hình ngoài.
- Đổi display scale/resolution.
- Đóng/mở nắp MacBook.
- Accessibility/Microphone/Notification permission denied rồi grant sau.
- Xiaozhi disconnect/reconnect khi stream transcript.
- Script build fail/cancel/timeout.
- Flood 1,000 event để xác minh rate-limit/backpressure.

---

## 17. Lộ trình phát triển

### Sprint 0 — Architecture spike (2–3 ngày)

**Deliverables**

- Khởi tạo monorepo/Xcode workspace + Swift packages.
- Viết `Docs/architecture.md`, `event-protocol.md`, `module-sdk.md`, `action-manifest.md`.
- Implement `NotchDomain` core model và test.
- CI: build + test + lint/format cơ bản.
- Quyết định minimum macOS 14, naming, module boundaries.

**Exit criteria**

- App rỗng compile được.
- Pure-domain tests pass.
- Không có feature UI vội vàng.

### Sprint 1 — Notch surface shell (1 tuần)

**Deliverables**

- Menu bar app + Settings window tối thiểu.
- `NSPanel` trên built-in display.
- Collapsed/compact/expanded state.
- Hover/click/Escape/click-outside/timeout.
- `InteractionStateMachine` có test.
- Debug overlay hiển thị surface state/frame/screen info.

**Exit criteria**

- App hoạt động ổn định sau các test cơ bản sleep/wake, đổi Space và full-screen policy.

### Sprint 2 — Core runtime, actions, IPC (1 tuần)

**Deliverables**

- Module runtime register/start/stop.
- EventBus, EventRouter, envelope v1.
- Action registry/executors cơ bản.
- Unix socket hoặc HTTP loopback.
- `notchctl` CLI.
- Action sample: Open URL, open app, show toast.

**Exit criteria**

- `notchctl emit ...` đổi compact UI.
- `notchctl action ...` chạy action allow-listed.
- Input invalid bị reject an toàn.

### Sprint 3 — Xiaozhi v1 (1 tuần)

**Deliverables**

- `xiaozhi-relay` hoặc `XiaozhiBridgeAdapter`.
- Xiaozhi module với states và transcript assembler.
- Compact status + expanded transcript UI.
- Reconnect strategy, diagnostics và token handling.
- Action: push-to-talk/stop/mute nếu backend hỗ trợ.

**Exit criteria**

- Một cuộc voice session hiển thị mượt: Listening → Thinking → Speaking.
- Transcript streaming không lag và không vỡ tiếng Việt.

### Sprint 4 — Utility modules (1–2 tuần)

**Deliverables**

- Chọn tối đa 2–3 trong Media, Clipboard, Files, System controls.
- Module settings, permission flow nếu feature cần.
- Chỉnh `PresentationPolicy` để các module không tranh UI.

**Exit criteria**

- Có thể bật/tắt từng module.
- Feature khác vẫn hoạt động khi một module unavailable hoặc permission bị deny.

### Sprint 5 — Developer tools và ESP gateway (1–2 tuần)

**Deliverables**

- Workspace profile cho ESP-IDF.
- Build/flash/monitor action profile.
- Gateway status adapter/Event API.
- Tool progress UI và action confirmation.
- Quick link tới local dashboard/repo/serial terminal.

**Exit criteria**

- Voice hoặc action UI có thể khởi động tool đã allow-list.
- Notch hiển thị build/OTA/gateway status nhưng không bị tràn log.

### Sprint 6 — Hardening/release preparation (1–2 tuần)

**Deliverables**

- Diagnostics export, log redaction, settings migration.
- Test matrix/manual QA complete.
- Launch at login policy.
- Signing/notarization investigation.
- Release workflow và changelog.

**Exit criteria**

- App dùng ổn định hằng ngày trong 1–2 tuần.
- Lỗi có đủ log/context để tự debug.

### Ước lượng tổng

P0 đến P2: khoảng **7–11 tuần part-time** cho một bản cá nhân chất lượng tốt. Thời gian thay đổi theo mức quen thuộc Swift/AppKit, scope của media/files/system controls và mức độ tích hợp Xiaozhi native audio.

---

## 18. Milestone và tiêu chí “base project đã đủ tốt”

Chỉ mở rộng feature nhanh khi tất cả điều dưới đây đều đúng:

- Có thể thêm module mới mà không sửa `NotchPanelController`.
- Module không được chạm trực tiếp vào `NSPanel`.
- Xiaozhi có thể bị disable nhưng core UI/app vẫn chạy bình thường.
- Module lỗi không crash toàn app.
- UI không parse raw Xiaozhi/WebSocket/ESP-IDF output.
- Mọi external input được validate vào `EventEnvelope` versioned.
- Không có đường nào cho AI chạy arbitrary shell command.
- Action side-effect có allow-list, schema validation và confirmation policy.
- Secret/token được lưu Keychain, không ghi plain text trong log/UserDefaults.
- IPC local mặc định không expose LAN.
- Có test state machine, event ordering, transcript buffering và action authorization.
- Có debug/diagnostics panel và export log có redaction.
- Manual test checklist cho sleep/wake, display, Spaces và full-screen đã pass.

---

## 19. Những anti-pattern cần tránh

1. **Một `ObservableObject` khổng lồ** chứa UI, WebSocket, settings, process runner và mọi feature.
2. **Module gọi trực tiếp module khác** thay vì event/action contract.
3. **Mỗi module tự show/hide notch panel**.
4. **Render text streaming cho từng token** trực tiếp trên main actor.
5. **Nhận shell command từ AI qua JSON rồi `Process()` ngay lập tức**.
6. **Xin Accessibility, Microphone, Camera, Screen Recording ngay lúc launch**.
7. **Bind WebSocket/HTTP server vào toàn LAN không authentication**.
8. **Mặc định lưu đầy đủ voice transcript và log chứa token**.
9. **Cố giải quyết multi-display, AirDrop, webcam, calendar, OCR và native audio ở MVP**.
10. **Phụ thuộc private macOS APIs trong core architecture**.
11. **Fork Boring Notch nguyên khối và coi đó là platform architecture**.
12. **Không có manual test cho Space/full-screen/sleep/external display**.

---

## 20. Thứ tự khởi tạo code thực tế

### Ngày 1

- Tạo Git repository `notch-hub`.
- Tạo Xcode app macOS 14+, SwiftUI lifecycle.
- Tạo Swift packages: `NotchDomain`, `NotchCore`, `NotchSurface`.
- Viết các ID type: `ModuleID`, `ActionID`, `SessionID`.
- Viết `SurfaceState`, `AssistantState`, `EventEnvelope`.
- Thiết lập SwiftFormat/SwiftLint nếu phù hợp và GitHub Actions build/test.

### Ngày 2

- Tạo `MenuBarExtra`.
- Implement `NotchPanelController` tối thiểu.
- Render `CollapsedNotchView` và `ExpandedNotchView` giả lập.
- Viết state machine và tests cho state transition.

### Ngày 3

- Tạo `EventBus` actor.
- Tạo `PresentationPolicy`.
- Tạo `ModuleRuntime` và dummy module.
- Dùng dummy event để hiện compact status.

### Ngày 4–5

- Tạo `NotchActions`, một URL action, một safe local action.
- Tạo HTTP loopback hoặc Unix socket tối thiểu.
- Viết `notchctl emit assistant.state --state listening`.
- Đưa event CLI lên Notch.

Sau mốc này, bạn có một base project thật: UI surface, module runtime, event contract, action boundary và IPC đã tồn tại. Xiaozhi, ESP32 hay media chỉ là consumer/producer của các contract đó.

---

## 21. Ví dụ flow hoàn chỉnh

### Voice hỏi Xiaozhi về gateway

```text
1. User nói với Xiaozhi ESP32:
   “Kiểm tra gateway BLE có bao nhiêu thiết bị đang kết nối.”

2. Xiaozhi backend/relay phát event:
   assistant.state = listening → thinking

3. NotchHub nhận event qua loopback WebSocket:
   Compact Notch hiện “Xiaozhi đang suy nghĩ…”

4. Xiaozhi gọi tool đã đăng ký:
   gateway.get_status

5. Gateway module/bridge trả tool.progress rồi tool.completed:
   “BLE gateway: 4 thiết bị online.”

6. Relay phát assistant.transcript.delta/final.

7. Xiaozhi module cập nhật transcript assembler;
   Notch hiển thị phần text mới nhất, giữ full conversation trong detail window.

8. User click Notch:
   Mở detail transcript/tool history; không cần reread raw protocol.
```

### Build firmware từ Notch

```text
1. User click “Build ESP32” trong expanded panel.
2. NotchActions lookup `developer.idf.build`.
3. Action policy xác định đây là action allowed/no confirmation hoặc cần confirmation tùy user setting.
4. Shell executor chạy profile `idf.py build` ngoài main actor.
5. Process output parser chỉ publish summary/progress throttled.
6. Compact Notch hiện “Đang build esp-ble-gateway…”.
7. Khi hoàn tất, `developer.build.finished` publish duration/result.
8. Notch hiển thị success/failure và có button “Open log”.
```

---

## 22. Kết luận

Dự án nên bắt đầu như một **platform modular dành cho notch**, không phải clone Boring Notch và cũng không phải chỉ là client Xiaozhi. Boring Notch là nguồn tham khảo rất tốt về SwiftUI/AppKit notch interaction, window management, feature organization và edge cases của macOS; nhưng base architecture nên được thiết kế mới để ưu tiên module contracts, event-driven integration, action security và khả năng mở rộng theo workflow AI + ESP32 của bạn.

Bản đầu có giá trị cao nhất là:

1. Notch surface ổn định với state machine rõ ràng.
2. Menu bar/settings/diagnostics như recovery path.
3. Module runtime + event contract v1.
4. Action registry có allow-list và confirmation policy.
5. Local IPC + `notchctl`.
6. Xiaozhi relay/module cho voice state và transcript.
7. Sau đó mới thêm media, clipboard, files, ESP-IDF và ESP BLE gateway.

Nếu giữ đúng boundaries này, sau vài tháng app vẫn có thể phát triển thành một command/status surface chung cho Xiaozhi, AI agents, ESP32 gateway, workflow firmware, automation và các tiện ích macOS mà không cần rewrite toàn bộ core.

---

## 23. Tài liệu nên viết tiếp

Sau tài liệu này, nên tạo các file thiết kế chi tiết sau:

- `Docs/event-protocol.md`: JSON schemas v1, event types, ordering, compatibility.
- `Docs/module-sdk.md`: lifecycle, capability restrictions, UI contribution contract.
- `Docs/action-manifest.md`: action schemas, executor contracts, confirmation/security policy.
- `Docs/ipc-security.md`: auth, socket path, token lifecycle, rate limit, LAN future plan.
- `Docs/notch-surface.md`: `NSPanel`, geometry, state machine, input policies.
- `Docs/xiaozhi-integration.md`: relay adapter, session model, transcript/audio level mapping.
- `Docs/developer-tools.md`: workspace profile, ESP-IDF process runner, serial/gateway integration.
- `Docs/testing.md`: test pyramid, fixtures, CI, manual device/display matrix.
- `Docs/references.md`: Boring Notch, Apple documentation, licenses and implementation notes.
