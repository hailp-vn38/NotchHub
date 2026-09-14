# NotchHub `dev` — Documentation Cleanup Plan

## Contract mới

1. Menu bar chỉ còn:
   - `Settings`
   - `Restart`
   - `Quit`

2. Notch Surface luôn bật:
   - không có `Toggle Notch Surface`;
   - không có setting `Enable Notch surface`;
   - không có user action `app.toggleSurface`;
   - khi app start, Surface tự vào trạng thái an toàn `collapsed`.

3. Không còn generic **NotchHub Detail View**:
   - không còn `DetailWindowCoordinator`;
   - không còn `DetailNavigationRequest`;
   - không còn `DetailWindowRootView`;
   - không còn button `View detail`;
   - `Detail window` không còn là presentation layer của NotchHub.

> `hidden`, `suppressed`, `recovering` vẫn có thể giữ làm state nội bộ phục vụ lifecycle/recovery. “Always-on Surface” không có nghĩa là panel phải visible khi sleep, full-screen suppression hoặc recovery failure.

---

## 1. File cần xoá hẳn

### Code

| File | Action | Lý do |
|---|---|---|
| `Packages/NotchSurface/Sources/DetailWindowCoordinator.swift` | **DELETE** | File chỉ tồn tại để implement generic NotchHub Detail View. |

### Docs

**Không có file Markdown nào trong `docs/` nên xoá nguyên file.**

Các tài liệu hiện tại chứa cả contract hợp lệ lẫn contract cũ, vì vậy nên sửa section thay vì delete toàn bộ file.

---

## 2. Tài liệu bắt buộc sửa — P0

### `docs/product/requirements.md`

Xoá/sửa:

- definition `Detail view`;
- yêu cầu user có thể hide/reveal Surface bằng menu;
- `FR-APP-003` menu cũ;
- user enable/disable Surface;
- `FR-SUR-011` về separate Detail View;
- `app.toggleSurface` khỏi minimum foundation actions.

Menu contract mới:

```text
Settings
Restart App Shell
Quit
```

`app.openDiagnostics`, `surface.showDemoStatus`,
`surface.toggleDebugOverlay` có thể vẫn tồn tại ở Action Registry nếu cần,
nhưng không được expose trong MenuBarExtra.

---

### `docs/product/roadmap.md`

#### F1

Xoá khỏi menu:

```text
Toggle Notch Surface
Show Demo State
Open Diagnostics
```

Thay bằng:

```text
Settings
Restart App Shell
Quit
```

#### F2

Xoá:

```text
explicit navigation path from expanded content
to a separate detail view/window
```

#### F6

Xoá:

```text
app.toggleSurface
```

khỏi foundation actions.

---

### `docs/architecture/notch-surface.md`

Xoá:

- `DetailWindowCoordinator` khỏi ownership model;
- `DetailWindowCoordinator.swift`;
- `DetailWindowRootView.swift`;
- generic detail-navigation contract;
- `userEnabledSurface`;
- `userDisabledSurface`;
- transition `hidden → collapsed` do user enable;
- transition `collapsed → hidden` do user disable;
- menu-bar Toggle Surface;
- click action mở placeholder Detail View.

State flow mới:

```text
app start
   ↓
collapsed

collapsed ↔ compact ↔ expanded

full-screen/privacy policy → suppressed
display/panel invalid      → recovering
recovery failure           → hidden
```

`hidden` là operational state, không phải user preference.

---

### `docs/design/notch-interaction.md`

Xoá:

- `Detail window` khỏi presentation model;
- toàn bộ section `Detail interaction`;
- `Click detail affordance`;
- `Open details`;
- `View full history`;
- `Open conversation` nếu route vào generic Detail View;
- `surface toggle action`;
- `Menu bar → Toggle NotchHub`;
- keyboard shortcut → `app.toggleSurface`;
- mô tả `Hidden` do user disable Surface.

Presentation model mới:

```text
Passive indicator
Compact Notch
Expanded panel
```

Settings và Diagnostics là application scenes độc lập, không phải Surface layer.

---

### `docs/design/settings-information-architecture.md`

Xoá setting:

```text
Enable Notch surface
```

Thay bằng:

```text
Surface is always enabled.
Notch Behavior configures interaction and presentation only.
```

Xoá shortcut:

```text
Toggle Notch
⌥⌘Space → app.toggleSurface
```

Xoá `app.toggleSurface` khỏi action catalogue.

Không cần xoá:

```text
Settings → Modules → <Module>
```

vì đây là Settings page, không phải generic NotchHub Detail Window.

---

### `docs/architecture/overview.md`

Xoá:

- “long-form detail presented in a separate window”;
- Detail Window khỏi interaction channels;
- separate detail-window coordination khỏi `NotchSurface`;
- `DetailWindowCoordinator` khỏi component architecture.

Giữ Settings và Diagnostics như window/scene độc lập.

---

### `docs/architecture/c4-container.md`

Xoá khỏi `NotchSurface` responsibility:

```text
separate DetailWindowCoordinator for explicitly requested long-form views
```

Sửa App Shell/Menu description để menu không còn đại diện cho Surface toggle,
Diagnostics, Demo hoặc Debug actions.

---

### `docs/architecture/state-management.md`

Xoá contract cũ:

```swift
case toggle
case showDetail(route: DetailRoute)
```

Xoá:

- `detail-navigation`;
- `DetailWindowCoordinator`;
- presentation example dùng Detail Window;
- user-opened module detail → separate Detail Window.

Surface command nên tập trung vào:

```text
expand
collapse
compact/status
suppress
recover
```

---

### `docs/architecture/action-platform.md`

Xoá:

```text
app.toggleSurface
⌥⌘Space → app.toggleSurface
```

Không bắt buộc xoá:

```text
app.openDiagnostics
surface.showDemoStatus
surface.toggleDebugOverlay
```

nếu vẫn cần ở Settings, development tooling hoặc diagnostics.

Nhưng chúng phải được đánh dấu:

```text
not exposed in MenuBarExtra
```

---

### `docs/platform/macos-lifecycle.md`

Xoá/sửa:

```text
Running, idle | Collapsed/hidden per Settings
```

và các nội dung:

- user disable Surface;
- module Detail Window;
- Detail Window restoration;
- Detail Window privacy behavior;
- direct Diagnostics access từ menu bar.

Lifecycle mới:

```text
running + valid display → collapsed / compact / expanded
full-screen/privacy     → suppressed
sleep/session change    → paused/suppressed
recovery failure        → hidden
```

---

### `docs/product/vision.md`

Xoá:

- Detail Window khỏi progressive-disclosure model;
- separate Detail View khỏi base-platform scope;
- user-configurable hidden Surface.

Product presentation model còn:

```text
Passive indicator
Compact Notch
Expanded panel
```

---

### `README.md`

README hiện còn mô hình 4 lớp có `Detail window`.

Sửa thành:

```text
Passive indicator
Compact Notch
Expanded panel
```

Thay rule cũ bằng:

```text
The Notch is for glanceable information and short interactions.
Configuration and diagnostics live in dedicated application scenes.
```

---

## 3. QA documentation phải sửa

### `docs/quality/testing-strategy.md`

Xoá:

- test old menu intents;
- user disable Surface;
- Detail navigation state-machine tests;
- UI automation mở separate Detail Window.

Thêm acceptance:

```text
MenuBarExtra contains exactly:
- Settings
- Restart
- Quit

Surface:
- starts automatically
- reaches collapsed without a user toggle
- has no user-facing enable/disable action
```

---

### `docs/quality/manual-qa.md`

Foundation smoke test phải bỏ:

```text
Open Diagnostics from menu
Toggle Notch surface
Trigger Demo status from menu
```

Menu smoke test mới:

```text
Open Settings
Restart
Quit
```

Xoá:

- `QA-SUR-006 — Detail route`;
- detail-specific Escape/back tests;
- Detail references trong display/sleep/lock cases;
- expectation rằng menu hoặc shortcut có thể toggle Surface.

Debug Overlay vẫn có thể test bằng development hook/action,
nhưng không expose trong menu bar.

---

## 4. Tài liệu lịch sử không nên xoá

### `docs/quality/f2-evidence.md`

**KEEP.**

Đây là historical evidence của implementation cũ.

Không sửa evidence quá khứ để phản ánh contract mới.

Sau refactor nên tạo evidence mới, ví dụ:

```text
docs/quality/f2-contract-refactor-evidence.md
```

---

### `docs/architecture/decisions/0004-menu-bar-as-recovery-surface.md`

**Không delete ADR đã Accepted.**

ADR hiện ghi menu có Surface toggle, Settings, Diagnostics, Restart và Quit.

Nên:

```text
Status: Superseded
```

và thêm ADR mới, ví dụ:

```text
0014-always-on-surface-and-minimal-menu.md
```

Decision mới:

```text
Menu bar exposes only Settings, Restart, and Quit.

The Notch Surface is always enabled and has no
user-facing enable/disable/toggle command.

The generic NotchHub Detail Window is removed.
```

---

## 5. Tài liệu P1 cần search lại khi implementation

| File | Kiểm tra |
|---|---|
| `docs/index.md` | Phase summaries còn mô tả contract F1/F2 cũ hay không. |
| `docs/design/accessibility.md` | Generic Detail focus/back requirements. |
| `docs/architecture/module-system.md` | Generic Detail UI contribution/route. |
| `docs/architecture/event-protocol.md` | `detail-navigation` hoặc `app.toggleSurface`. |
| `docs/architecture/ipc.md` | `app.toggleSurface` trong action examples. |

---

## 6. Tài liệu có thể giữ

```text
docs/design/notchhub-boring-hover-surface-implementation.md
```

Tài liệu này chủ yếu mô tả:

- geometry;
- hover;
- shape/radius;
- animation;
- hit testing;
- persistent SwiftUI hierarchy.

Các contract này vẫn phù hợp với Surface always-on.

---

## 7. Source code cần đồng bộ

| File | Change |
|---|---|
| `Apps/NotchHubApp/NotchHubApp.swift` | Chỉ render Settings / Restart / Quit; bỏ Detail wiring. |
| `Packages/NotchCore/Sources/AppCoordinator.swift` | Bỏ menu intents toggle/debug/demo/diagnostics khỏi menu contract. |
| `Packages/NotchSurface/Sources/DetailWindowCoordinator.swift` | **DELETE** |
| `Packages/NotchSurface/Sources/SurfaceCoordinator.swift` | Bỏ `NotchSurfaceToggling`, `detailInput`, `detailNavigator`. |
| `Packages/NotchSurface/Sources/NotchPanelController.swift` | Bỏ `DetailNavigationInput` và detail handler. |
| `Packages/NotchSurface/Sources/NotchSurfacePresentation.swift` | Bỏ `openDetail` và `View detail`. |
| `Tests/NotchPackageSpineTests/NotchPackageSpineTests.swift` | Xoá toggle/detail tests; thêm always-on/menu tests. |

---

## 8. Startup contract đề xuất

Không nên thay toggle bằng cách gọi một “fake toggle” khi launch.

Nên explicit:

```text
AppCoordinator.start()
      ↓
SurfaceCoordinator.start()
      ↓
validate display
      ↓
show collapsed surface
```

Contract phù hợp hơn:

```swift
protocol NotchSurfaceLifecycleControlling {
    func start()
    func stop()
    func handleAppShellLifecycle(_ event: AppShellLifecycleEvent)
}
```

thay vì:

```swift
protocol NotchSurfaceToggling {
    func toggleNotchSurface()
}
```

---

## 9. Checklist

- [ ] Menu bar chỉ có `Settings`, `Restart`, `Quit`.
- [ ] Không còn `Toggle Notch Surface`.
- [ ] Không còn `Open Diagnostics` trong menu.
- [ ] Không còn `Show Demo State` trong menu.
- [ ] Không còn Debug Overlay trong menu.
- [ ] Không còn setting `Enable Notch surface`.
- [ ] Không còn action `app.toggleSurface`.
- [ ] Surface tự start ở `collapsed`.
- [ ] `hidden` chỉ phục vụ lifecycle/recovery.
- [ ] Xoá `DetailWindowCoordinator.swift`.
- [ ] Không còn `DetailWindowCoordinator`.
- [ ] Không còn `DetailNavigationRequest`.
- [ ] Không còn `DetailWindowRootView`.
- [ ] Không còn button `View detail`.
- [ ] Không còn generic `Detail window` trong product model.
- [ ] Settings/Diagnostics là application scenes riêng.
- [ ] Giữ `f2-evidence.md` làm historical evidence.
- [ ] Supersede ADR-0004 thay vì delete.
- [ ] Update requirements → roadmap → architecture → design → QA trong cùng PR.

## Kết luận

**Xoá nguyên file:**

```text
Packages/NotchSurface/Sources/DetailWindowCoordinator.swift
```

**Không xoá nguyên file docs.**

Các docs P0 cần refactor:

```text
README.md
docs/product/requirements.md
docs/product/roadmap.md
docs/product/vision.md
docs/architecture/notch-surface.md
docs/architecture/overview.md
docs/architecture/c4-container.md
docs/architecture/state-management.md
docs/architecture/action-platform.md
docs/platform/macos-lifecycle.md
docs/design/notch-interaction.md
docs/design/settings-information-architecture.md
docs/quality/testing-strategy.md
docs/quality/manual-qa.md
```

Giữ lịch sử:

```text
docs/quality/f2-evidence.md
docs/architecture/decisions/0004-menu-bar-as-recovery-surface.md
```

ADR-0004 nên được supersede, không xoá.