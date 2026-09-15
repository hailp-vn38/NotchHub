# NotchHub Settings UI Specification

> UI specification for the NotchHub Settings window, derived from
> [`docs/design/settings-information-architecture.md`](settings-information-architecture.md).
> It defines presentation and interaction rules; capability ownership remains phased in the
> [roadmap](../product/roadmap.md).

## 1. Mục tiêu

Settings là **control, explanation, recovery và trust surface** của NotchHub.

UI phải giúp người dùng:

- Hiểu NotchHub đang hoạt động như thế nào.
- Điều chỉnh hành vi của Notch surface.
- Quản lý shortcuts và actions.
- Hiểu permission nào đang được sử dụng và lý do.
- Bật/tắt và cấu hình modules.
- Chẩn đoán lỗi và đi tới đúng recovery action.
- Xem thông tin ứng dụng, version và privacy.

Settings phải là **một cửa sổ macOS riêng**, không render bên trong compact/expanded Notch surface.

### Trạng thái hiện tại

F5 Permission Center đã có automated implementation gate; native manual permission gate vẫn
pending. F2 và F3 vẫn có native manual gate riêng chưa được đóng; F4 có evidence persistence hoàn tất. Branch đã có F3 Settings shell: Settings mở thành
application scene với 9 route, shared `NotchUI` components, navigation accessibility, và motion
preview chỉ trong phiên. Các control, dữ liệu, và trạng thái còn lại trong tài liệu này là mục tiêu
có chủ sở hữu theo pha bên dưới; chúng không phải bằng chứng rằng capability đã hoạt động. Trước
khi chủ sở hữu xuất hiện, route phải dùng unavailable state rõ ràng và không nhận input có side
effect.

---

## 1.1 Phân bổ ownership F4–F9

F3 cung cấp `Settings shell`, navigation, visual token/component, accessibility, và placeholder.
Những phần còn lại của specification này chỉ được triển khai khi pha sở hữu bắt đầu.

| Pha | Phần Settings UI được hiện thực | Không làm trong pha này |
|---|---|---|
| F4 — Typed settings | Toggle/preset row có validation; preview an toàn; applying/rollback; reset scopes; import/export non-secret; trạng thái saved/error từ `SettingsStore` | Permission request, shortcut capture, Action execution, module lifecycle, operational diagnostics |
| F5 — Permission Center | Permission groups; friendly capability/status/reason; pre-prompt explanation; denied/revoked state; System Settings recovery; Notifications recovery opt-in | Request một capability không do user khởi tạo; module tự gọi privacy API; general notification policy |
| F6 — Actions & shortcuts | Action row, result/availability, confirmation route; shortcut recorder, clear/disable/conflict state | Callback business logic trong view; arbitrary command/executor input |
| F7 — Module runtime | Module list/detail, enablement, lifecycle/health/error projection, module settings route | Start module bị disable chỉ để render page; module tạo top-level route |
| F8 — EventBus & local IPC | Bounded local IPC health/status and recovery summary when an owned route exists | Token, authorization header, raw request/payload, LAN control |
| F9 — Diagnostics | Health/surface/resource summary; bounded sanitized records; copy/export diagnostics; recovery routes | Raw log viewer, secret/user-content export, unbounded polling/history |

Mọi control chỉ gọi typed intent vào owner của pha. Nếu owner chưa tồn tại, component phải là
status/unavailable row, không phải disabled toggle mơ hồ hoặc fake preference.

---

## 2. Layout tổng thể

### 2.1 Window

Thiết kế theo macOS Settings convention:

```text
┌─────────────────────────────────────────────────────────────┐
│ Toolbar / Window chrome                                     │
├────────────────┬────────────────────────────────────────────┤
│ Sidebar        │ Content                                    │
│                │                                            │
│ General        │ Page title                                 │
│ Appearance     │ Subtitle / explanation                     │
│ Notch Behavior │                                            │
│ Shortcuts      │ Section                                    │
│ Permissions    │ ┌────────────────────────────────────────┐ │
│ Actions        │ │ Setting row                            │ │
│ Modules        │ ├────────────────────────────────────────┤ │
│ Diagnostics    │ │ Setting row                            │ │
│ About          │ └────────────────────────────────────────┘ │
│                │                                            │
└────────────────┴────────────────────────────────────────────┘
```

### 2.2 Kích thước

Khuyến nghị:

- Minimum width: `760 pt`
- Preferred width: `900–1040 pt`
- Minimum height: `560 pt`
- Sidebar width: `190–220 pt`
- Content max readable width: `680–760 pt`

Không hard-code kích thước panel theo từng page. Nội dung dài sử dụng scroll view.

---

## 3. Navigation

Top-level Settings cố định:

```text
Settings
├── General
├── Appearance
├── Notch Behavior
├── Shortcuts
├── Permissions
├── Actions
├── Modules
├── Diagnostics
└── About
```

### Quy tắc

- Module không được tạo top-level page riêng.
- Module settings phải nằm dưới:

```text
Settings → Modules → <Module Name>
```

Ví dụ:

```text
Settings → Modules → Xiaozhi Display Companion
Settings → Modules → Media
Settings → Modules → Clipboard
```

- Deep link chỉ thay đổi route.
- Deep link **không tự request permission, execute action hoặc start module**.

---

## 4. Visual language

### 4.1 Style

UI nên mang cảm giác:

- Native macOS.
- Nhẹ.
- Ít chrome.
- Nội dung có hierarchy rõ.
- Trạng thái quan trọng dễ nhận biết.
- Không biến Settings thành dashboard.

### 4.2 Background

- Window background: sử dụng semantic macOS background.
- Sidebar: nhẹ hơn hoặc tách bằng material/divider.
- Settings groups: có thể dùng card/grouped container nhẹ.
- Không dùng shadow nặng.

### 4.3 Spacing

Khuyến nghị token:

```text
4   — micro spacing
8   — control internal spacing
12  — row spacing
16  — section spacing
20  — standard content padding
24  — major section spacing
32  — page block spacing
```

### 4.4 Corner radius

- Small control: `6–8 pt`
- Group/card: `10–12 pt`
- Không sử dụng radius quá lớn kiểu mobile card.

### 4.5 Typography

```text
Page title       : title2 / bold
Section title    : headline
Row title        : body / medium
Row description  : subheadline / secondary
Status/helper    : caption / secondary
Error            : caption/body + semantic error treatment
```

---

## 5. Sidebar

Mỗi item gồm:

```text
[SF Symbol]  Page name
```

Đề xuất icon:

| Page | SF Symbol |
|---|---|
| General | `gearshape` |
| Appearance | `paintbrush` |
| Notch Behavior | `macbook` |
| Shortcuts | `keyboard` |
| Permissions | `lock.shield` |
| Actions | `bolt` |
| Modules | `square.grid.2x2` |
| Diagnostics | `waveform.path.ecg` |
| About | `info.circle` |

### Selected state

- Background tint nhẹ.
- Icon + label giữ contrast tốt.
- Không phụ thuộc màu duy nhất để thể hiện selected state.

---

# 6. Common Settings Components

## 6.1 Section

```text
Section title
Optional section description

┌───────────────────────────────────────────┐
│ Row                                       │
├───────────────────────────────────────────┤
│ Row                                       │
└───────────────────────────────────────────┘
```

Section phải có mục đích rõ ràng, tránh chia quá nhỏ.

---

## 6.2 Standard toggle row

Dùng cho boolean preference.

```text
Title                                      [Toggle]
Short explanation
Optional helper/error text
```

Ví dụ:

```text
Example preference                          [ ON ]
Short explanation of the setting's effect.
```

### Behavior

- UI update ngay nếu an toàn.
- Persistence thông qua typed settings.
- Nếu persist thất bại, quay về last-known-good state hoặc thể hiện lỗi rõ ràng.
- Disabled row phải giải thích nguyên nhân.

---

## 6.3 Selection / preset row

Dùng cho bounded values.

```text
Title                                  [ Standard ▾ ]
Explanation
```

Dùng cho:

- Theme.
- Hover delay.
- Auto-collapse timeout.
- Layout preset.
- Start state.

Không cho nhập raw width/height hoặc low-level window flags.

---

## 6.4 Action row

```text
Title                                      [ Run ]
What this action does
Status / last result
```

Action phải route qua `ActionRegistry`.

Không đặt business logic trực tiếp trong button callback.

---

## 6.5 Permission row

```text
[Icon] Microphone                  Not used
       Used only by modules requiring voice input.

                                  [Details]
```

Khi cần permission:

```text
[Icon] Accessibility               Denied
       Required by Global Shortcuts.

                     [Open System Settings]
```

Permission row phải hiển thị:

- Friendly capability name.
- Current state.
- Module/feature yêu cầu.
- Lý do.
- Hành vi nếu từ chối.
- Recovery action.

---

## 6.6 Destructive row

```text
Reset Settings

Reset all non-secret NotchHub preferences.
Credentials are not removed.

                               [ Reset Settings ]
```

### Rules

- Tách khỏi controls thông thường.
- Giải thích chính xác scope.
- Require confirmation.
- Không gộp reset settings và delete credentials.

---

## 6.7 Status-only row

```text
Version                             0.1.0
Runtime                              Running
IPC                                  Local only
```

Không làm status-only row trông giống editable preference.

---

# 7. Page Specifications

## 7.1 General

### Header

```text
General
Basic application behavior and recovery.
```

### Sections

#### Startup

- Launch at login.
- Chỉ hiện khi implementation đã sẵn sàng.
- Nếu chưa có: hide hoặc hiển thị unavailable rõ ràng, không dùng fake toggle.

#### Application

- Start behavior.
- Restore last safe surface state.

Không tự restore expanded/detail state khi launch.

#### Configuration

- Export settings.
- Import settings.
- Reset non-secret settings.

Import phải validate trước khi apply.

#### Recovery

- Restart runtime.

Restart đi qua registered action.

---

## 7.2 Appearance

### Header

```text
Appearance
Customize visual presentation without changing app behavior.
```

### Sections

#### Theme

```text
Appearance
(•) System
( ) Light
( ) Dark
```

#### Motion

```text
Reduce Motion                           [ Follow System ▾ ]
```

F4 chỉ cho phép Follow System hoặc Reduce Motion; không được buộc thêm motion trái với system
preference. Material, opacity, layout density, animation intensity, và indicator style là future
unavailable state, không phải controls F4.

---

## 7.3 Notch Behavior

### Header

```text
Notch Behavior
Control when and how the Notch surface appears.
```

### Sections

#### Surface

```text
Notch surface                            Always on when eligible
Startup state                            Collapsed
```

Đây là invariant từ ADR-0014, không phải controls. Settings không được cung cấp enable/disable,
toggle visibility, hoặc lựa chọn startup state cho Notch surface.

#### Pointer Interaction

```text
Hover delay                             [ 300 ms ▾ ]
```

Hover luôn enabled theo F2 interaction contract; F4 chỉ persist delay đã validate.
Allowed presets: `150 ms`, `300 ms`, và `500 ms`; default là `300 ms`.

#### Collapse Behavior

```text
Collapse after                          [ 3 seconds ▾ ]
```

Auto-collapse luôn enabled theo F2 interaction contract; F4 chỉ persist timeout đã validate.
Allowed presets: `2 seconds`, `3 seconds`, và `5 seconds`; default là `3 seconds`.

#### Keyboard / Interaction

- Escape collapses to safe state.
- Click outside collapses.

#### Context Policy

```text
Full-screen policy                      Suppress
```

Đây là invariant, không phải F4 control. Chỉ thêm preference khi một policy khác đã native-verified
và không ép Surface mở rộng trong khi ứng dụng khác đang full-screen.

#### Display

Foundation UI phải giải thích:

> NotchHub currently targets the built-in MacBook display first.

#### Debug

Chỉ debug/development builds:

```text
Surface Debug Overlay                   [ OFF ]
```

---

## 7.4 Shortcuts

### Header

```text
Shortcuts
Assign keyboard shortcuts to registered actions.
```

### Row

```text
Toggle Notch Surface             [ ⌥⌘Space ]
Show or hide the Notch surface.

Open Settings                    [ Record… ]
Open NotchHub Settings.

Open Diagnostics                 [ Record… ]
Open diagnostics and recovery.
```

### Rules

- Shortcut bind với `ActionID`.
- Validate conflict trước khi save.
- Clear shortcut chỉ remove binding.
- Action vẫn tồn tại.
- Unavailable action vẫn có thể hiển thị nhưng disabled + reason.

---

## 7.5 Permissions

### Header

```text
Permissions
See what NotchHub can access and why.
```

### Groups

```text
Required by Enabled Modules
Optional Capabilities
Not Currently Used
Privacy Information
```

### Example

```text
Accessibility                              Enabled
Used by global shortcut functionality.

Microphone                                 Not used
No enabled module currently uses microphone access.

Screen Recording                           Not used
NotchHub does not request this permission unless a feature needs it.
```

### Critical rule

Opening Settings hoặc Permissions page **không được tự trigger macOS permission prompt**.

---

## 7.6 Actions

### Header

```text
Actions
Registered operations available across NotchHub.
```

### Example row

```text
Toggle Notch Surface                   [ Run ]
app.toggleSurface

Available
Shortcut: ⌥⌘Space
Confirmation: Not required
```

### Foundation actions

- `app.toggleSurface`
- `app.openSettings`
- `app.openDiagnostics`
- `app.restartRuntime`
- `surface.showDemoStatus`
- `surface.toggleDebugOverlay`
- `settings.reset`
- `demo.ping`

Development actions phải ẩn khỏi normal release nếu không intended cho users.

---

## 7.7 Modules

### Header

```text
Modules
Manage optional NotchHub capabilities.
```

### Module card / row

```text
┌─────────────────────────────────────────────┐
│ Demo Module                         [ ON ]  │
│ Foundation test module                      │
│                                             │
│ ● Running                                   │
│ No permissions required                     │
│                                  [ Open › ] │
└─────────────────────────────────────────────┘
```

### Statuses

- Running
- Stopped
- Suspended
- Failed
- Unavailable

### Module detail

```text
Demo Module
├── Overview
├── Enablement & Health
├── Feature Settings
├── Permissions
├── Actions & Shortcuts
├── Data & Privacy
├── Performance
├── Diagnostics
└── Reset Module Data
```

Disabled module không được start chỉ để render Settings page.

---

## 7.8 Diagnostics

### Header

```text
Diagnostics
Inspect NotchHub health and recover from problems.
```

Diagnostics phải ưu tiên **health summary**, không phải raw log viewer.

### Sections

#### Health

```text
Runtime                         Running
Surface                         Collapsed
Modules                         1 running
IPC                             Local / Healthy
```

#### Surface

- Current state.
- Target display.
- Computed frame.
- Suppression/recovery reason.

#### Modules

- Health.
- Last sanitized error.
- Resource summary.

#### Permissions

- Current capability state.

#### Actions

- Recent bounded results.
- Timeout/cancellation count.

#### Events / IPC

- Accepted.
- Rejected.
- Dropped.
- Coalesced.
- Client count.

#### Performance

- CPU snapshot.
- Memory snapshot.
- Event/UI update rate.
- Buffer utilization.

#### Logs

- Sanitized.
- Bounded.
- Copy diagnostics.
- Export diagnostics.

### Important

Không hiển thị:

- Tokens.
- Authorization headers.
- Raw transcripts.
- Clipboard content.
- Camera/screen/audio content.

---

## 7.9 About

### Layout

Có thể dùng two-column layout:

```text
[App icon]   NotchHub
             Version 0.1.0
             Build 123

             A modular macOS Notch Platform
             for glanceable status and quick actions.

Documentation
License
Privacy
Security
Repository
Third-party notices
```

Không hiển thị internal build paths hoặc debug environment secrets.

---

# 8. Error UX

Error message phải theo pattern:

```text
What happened
Why it matters
What the user can do next
Optional Diagnostics link
```

Ví dụ:

```text
NotchHub could not apply the new display layout.

The built-in display is currently unavailable.

The previous layout remains active.

[Open Diagnostics]
```

Không dùng error chỉ gồm:

```text
Something went wrong.
```

---

# 9. Disabled State

Disabled control phải luôn trả lời được:

> Tại sao control này bị disabled?

Ví dụ:

```text
Use microphone                          [ OFF ]
Microphone is not used by any enabled module.
```

hoặc:

```text
Global Shortcut                         [ Disabled ]
Accessibility permission is required.

[Open Permissions]
```

---

# 10. Loading và Applying State

Không dùng global spinner cho toàn Settings window nếu chỉ một row đang làm việc.

Ví dụ:

```text
Layout preset                 Applying…
```

Nếu apply lỗi:

```text
Layout preset                 Standard
Could not apply Compact layout. Previous layout restored.
[Diagnostics]
```

---

# 11. Accessibility

Settings phải hỗ trợ:

- Keyboard-only navigation.
- VoiceOver.
- Logical focus order.
- Explicit labels/value/state.
- Textual disabled reasons.
- Error/status announcements.
- Reduced Motion.
- Light / Dark / System appearance.
- Sufficient contrast.

Không dùng màu làm tín hiệu duy nhất.

Ví dụ status:

```text
● Running
```

phải luôn có text `"Running"` thay vì chỉ green dot.

---

# 12. Performance Rules

Opening Settings không được:

- Start disabled modules.
- Request permission.
- Connect remote service/relay.
- Scan filesystem.
- Load full clipboard/transcript/log history.
- Recreate Notch panel.
- Persist value trong mỗi SwiftUI recomputation.

### Suggested refresh

| Page | Refresh |
|---|---|
| General | event-driven |
| Appearance | event-driven |
| Notch Behavior | event-driven |
| Shortcuts | registry/binding changes |
| Permissions | on entry / app activation / manual refresh |
| Actions | registry events |
| Modules | runtime health events |
| Diagnostics | max ~1–2 Hz while visible |
| About | static |

---

# 13. SwiftUI View Structure

Khuyến nghị structure:

```text
SettingsWindow
├── NavigationSplitView
│   ├── SettingsSidebar
│   └── SettingsContent
│
├── GeneralSettingsView
├── AppearanceSettingsView
├── NotchBehaviorSettingsView
├── ShortcutsSettingsView
├── PermissionsSettingsView
├── ActionsSettingsView
├── ModulesSettingsView
│   └── ModuleSettingsView
├── DiagnosticsSettingsView
└── AboutSettingsView
```

Common components:

```text
SettingsSection
SettingsToggleRow
SettingsPickerRow
SettingsActionRow
SettingsPermissionRow
SettingsDestructiveRow
SettingsStatusRow
SettingsErrorView
SettingsEmptyState
SettingsBadge
```

---

# 14. State Ownership

UI chỉ render projection của state.

```text
Settings UI
    ↓
Settings ViewModel
    ↓
Core service
```

| State | Owner |
|---|---|
| Durable settings | `SettingsStore` |
| Secret state | `SecretStore` / Keychain |
| Permissions | `PermissionCoordinator` |
| Actions | `ActionRegistry` |
| Modules | `ModuleRuntime` |
| Surface | `SurfaceCoordinator` |
| Diagnostics | `DiagnosticsStore` |

SwiftUI view không được trực tiếp:

- đọc/ghi raw `UserDefaults`,
- truy cập Keychain,
- request permission,
- thao tác `NSPanel`,
- execute module business logic.

---

# 15. Foundation UI Acceptance Criteria

Settings UI đạt yêu cầu foundation khi:

- Có đủ 9 navigation pages.
- Placeholder được ghi rõ và không giả vờ là feature đã hoạt động.
- Settings mở được độc lập với Notch surface.
- Layout hoạt động ở narrow/wide window.
- Keyboard navigation hoạt động.
- VoiceOver labels đầy đủ.
- Light / Dark / System hoạt động.
- Permission page không prompt tự động.
- Module page không start disabled module.
- Actions dùng `ActionID`.
- Destructive operation có confirmation.
- Error luôn có recovery path.
- Không expose secret/sensitive raw data.
- Diagnostics history bounded.
- UI không tạo high-rate polling khi idle.

---

# 16. Visual Direction

UI của NotchHub Settings nên ưu tiên:

**Calm**
: ít visual noise, section rõ ràng.

**Native**
: gần conventions của macOS hơn dashboard/web app.

**Inspectable**
: status và unavailable reason luôn nhìn thấy.

**Recoverable**
: lỗi luôn có route tiếp theo.

**Safe**
: permission, destructive action và secret management không bị biến thành toggle tùy tiện.

**Modular**
: module mới sử dụng cùng component và hierarchy, không phá navigation.

---

## Final UI hierarchy

```text
Settings Window
│
├── Sidebar
│   ├── General
│   ├── Appearance
│   ├── Notch Behavior
│   ├── Shortcuts
│   ├── Permissions
│   ├── Actions
│   ├── Modules
│   ├── Diagnostics
│   └── About
│
└── Content
    ├── Page header
    ├── Section
    │   └── Standard setting rows
    ├── Section
    │   └── Status / permission / action rows
    └── Recovery / destructive section when applicable
```

The Settings experience should remain stable as NotchHub grows. New capabilities are integrated through typed routes, shared components, and platform-owned services rather than introducing ad-hoc views or settings behavior.
