# NotchHub — Triển khai Hover Surface theo Boring Notch

**Phiên bản tài liệu:** v2 — cập nhật sau khi đọc source Boring Notch  
**Target:** `hailp-vn38/NotchHub`, branch `dev`  
**NotchHub baseline:** `379982f195c75c867954579d7cab3cc9a9fcbce0`  
**Boring Notch reference snapshot:** `TheBoredTeam/boring.notch` `main` tại commit `85af174f3b3894996152c5402f6569a987d86694`  
**Phạm vi:** F2 Notch Surface — geometry, hover, shape/radius, open/close animation và hit testing

---

## 1. Mục tiêu

Thay Surface F2 hiện tại của NotchHub từ một placeholder dạng:

```text
Capsule + "NotchHub"
```

thành một **notch-shaped Surface** giống cảm giác hình học và chuyển động của Boring Notch:

```text
collapsed physical-notch surface
        ↓ hover dwell
animated morph
        ↓
fixed expanded Surface 640 × 190
```

Yêu cầu cuối:

- collapsed Surface không còn bọc quanh `Text("NotchHub")`;
- kích thước collapsed dựa trên physical notch nếu có;
- expanded visual Surface cố định `640 × 190 pt`;
- hình dạng có hai loại radius:
  - closed: top shoulder `6`, bottom `14`;
  - opened: top shoulder `19`, bottom `24`;
- top shoulder cong vào trong giống notch, không phải rounded rectangle thông thường;
- hover khoảng `300 ms` mới mở;
- mouse rời Surface có `100 ms` grace trước khi đóng;
- open/close dùng spring khác nhau;
- expanded content scale/fade từ anchor `.top`;
- SwiftUI root được giữ ổn định để geometry có thể animate liên tục;
- `NotchPanelController` vẫn là component duy nhất sở hữu `NSPanel`;
- không để một transparent host `640 × 210` chặn click suốt thời gian collapsed.

---

# 2. Những gì source Boring Notch thực sự đang làm

Phần này là kết quả đọc source upstream, không phải suy đoán từ screenshot.

## 2.1 Kích thước

Trong `boringNotch/sizing/matters.swift`, upstream định nghĩa:

```text
openNotchSize = 640 × 190
shadowPadding = 20
windowSize    = 640 × 210
```

Điểm cần phân biệt:

```text
640 × 190 = visible open notch/surface
640 × 210 = native host window envelope
```

20 pt thêm vào host dành khoảng trống cho shadow/compositing phía dưới.

Collapsed size không phải một constant kiểu `136 × 46`. Upstream tính closed notch từ màn hình:

- width dựa trên khoảng giữa `auxiliaryTopLeftArea` và `auxiliaryTopRightArea`, cộng một tolerance nhỏ;
- height mặc định `32`;
- trên máy có notch có thể lấy `safeAreaInsets.top`;
- hoặc match menu-bar height tùy setting.

Vì vậy triết lý source là:

```text
closed = display-derived
open   = fixed product size
```

Đây là hướng nên áp dụng cho NotchHub.

---

## 2.2 `NSPanel` của Boring Notch là host cố định

Trong `boringNotchApp.swift`, Boring Notch tạo window với kích thước `windowSize` ngay từ đầu, đặt top-center màn hình và gắn **một** `NSHostingView(ContentView())`.

Window không bị thay bằng hosting root khác mỗi lần open/close.

Luồng thực tế gần với:

```text
NSPanel 640 × 210
    │
    └── ContentView, top-aligned
            │
            └── NotchLayout
                 closed geometry ↔ open geometry
```

`BoringViewModel.open()` chỉ đổi:

```text
notchSize  -> 640 × 190
notchState -> open
```

`close()` đưa `notchSize` trở lại closed size và `notchState` về closed.

**Kết luận quan trọng:** animation chính xảy ra ở SwiftUI content/shape bên trong một hosting hierarchy ổn định; upstream không tạo một SwiftUI root mới cho mỗi state.

---

## 2.3 Window configuration

Boring Notch dùng floating, transparent, non-main/non-key style panel:

```text
floating panel
opaque = false
background = clear
movable = false
window shadow = false

collection behavior:
- fullScreenAuxiliary
- stationary
- canJoinAllSpaces
- ignoresCycle
```

Window level upstream cao hơn menu chính.

NotchHub **không cần copy nguyên cấu hình**, vì F2 hiện đã có policy riêng cho focus, click-outside, fullscreen suppression và recovery. Chỉ lấy bài học:

> Native host phải transparent và ổn định; visual shape/shadow thuộc SwiftUI Surface.

---

# 3. Shape Boring Notch thực sự dùng

## 3.1 Không phải `RoundedRectangle`

`NotchShape.swift` có hai tham số:

```text
topCornerRadius
bottomCornerRadius
```

và cả hai nằm trong `animatableData`.

Path của upstream có đặc điểm hình học:

1. bắt đầu tại mép trên ngoài cùng;
2. dùng curve để đi **vào trong** một khoảng bằng top radius;
3. thành bên nằm inset so với mép ngoài;
4. góc dưới dùng bottom radius lớn hơn để đi ra mép đáy;
5. hai phía đối xứng.

Silhouette tương đương:

```text
screen edge
────────────────────────────────────

┐                                  ┌
 ╲                                ╱
  │                              │
  │                              │
  │                              │
   ╲                            ╱
    ╰──────────────────────────╯
```

Đây là lý do nhìn giống Surface “mọc ra” từ physical notch.

Một `RoundedRectangle` thông thường cho geometry khác:

```text
╭────────────────────────────────╮
│                                │
╰────────────────────────────────╯
```

Vì vậy **không dùng `Capsule` và không dùng `UnevenRoundedRectangle` làm implementation cuối**.

---

## 3.2 Radius upstream

`cornerRadiusInsets` upstream:

```text
opened:
    top    = 19
    bottom = 24

closed:
    top    = 6
    bottom = 14
```

Tên `topCornerRadius` trong upstream dễ gây hiểu nhầm. Với NotchHub nên gọi rõ hơn:

```swift
topShoulderRadius
bottomCornerRadius
```

vì top value điều khiển “shoulder” nối từ screen edge vào side wall.

---

## 3.3 Shape phải animatable

Không được chỉ swap hai shape khác nhau.

Target:

```text
topShoulderRadius: 6  → 19
bottomCornerRadius: 14 → 24
```

và SwiftUI interpolate chúng trong cùng một Shape instance/type.

---

# 4. Animation upstream

## 4.1 Open/close spring của layout

Trong `ContentView`, upstream dùng:

```text
OPEN:
response        = 0.42
dampingFraction = 0.80

CLOSE:
response        = 0.45
dampingFraction = 1.00
```

Ý nghĩa UX:

- open có một chút spring/liveliness;
- close gần critical damping, dừng gọn và không bounce trở lại.

Đây là cặp thông số nên dùng làm baseline cho NotchHub.

---

## 4.2 Shared interactive spring

Upstream còn có một shared `interactiveSpring` cho hover/movement:

```text
response        = 0.38
dampingFraction = 0.80
```

Nó được dùng khi đổi `isHovering` và khi `doOpen()` được gọi.

NotchHub không bắt buộc phải có hai lớp spring giống hệt, nhưng nên giữ:

```text
surface geometry open/close -> dedicated open/close spring
minor hover visual state    -> interactive spring
```

---

## 4.3 Expanded content transition

Khi `notchState == open`, upstream insert phần nội dung với transition:

```text
scale = 0.8
anchor = top
+ opacity
smooth duration ≈ 0.35 s
```

Do đó NotchHub nên dùng:

```swift
.transition(
    .scale(scale: 0.8, anchor: .top)
        .combined(with: .opacity)
)
```

Không dùng center-scale vì sẽ làm panel có cảm giác “phóng to từ giữa” thay vì mở xuống từ notch.

---

# 5. Hover behavior upstream

## 5.1 Hover enter

Upstream giữ một cancellable `hoverTask`.

Khi pointer enter:

1. cancel task cũ;
2. `isHovering = true`;
3. nếu đang closed, hover-open enabled và không có transient conflicting UI:
4. chờ `minimumHoverDuration`;
5. kiểm tra pointer vẫn hover;
6. gọi open.

Default của `minimumHoverDuration` là:

```text
0.3 s = 300 ms
```

Vì vậy nếu mục tiêu là “giống Boring Notch”, NotchHub nên đổi F2 default từ `150 ms` thành `300 ms`.

---

## 5.2 Hover exit

Khi pointer rời Surface upstream:

1. task cũ bị cancel;
2. tạo task mới;
3. chờ `100 ms`;
4. nếu task chưa bị cancel:
   - clear hover state;
   - nếu notch vẫn open và không có popover/share interaction đang giữ open;
   - close.

Điểm quan trọng không phải chỉ là `100 ms`, mà là:

```text
exit -> delayed close
re-enter -> cancel delayed close
```

Đây là anti-flicker mechanism.

---

## 5.3 Interaction locks

Boring Notch không đóng khi một số interaction đặc biệt đang active, ví dụ:

- battery popover;
- sharing flow.

NotchHub F2 hiện chưa có những feature này, nhưng tài liệu implementation nên dành seam cho tương lai:

```swift
var preventsHoverCollapse: Bool
```

hoặc một interaction-hold counter/token.

Không hard-code media/battery/share vào `NotchSurface`.

---

# 6. Shadow và top seam

Upstream không dùng native AppKit window shadow. SwiftUI Surface tự tạo shadow.

Khi open hoặc hovering, upstream dùng black shadow với opacity khoảng `0.7`; radius thường `6` khi corner scaling được bật.

Ngoài ra upstream đặt một black strip `1 pt` ở top, inset ngang theo top radius. Đây là chi tiết nhỏ nhưng hữu ích để tránh anti-alias seam giữa black Surface và top edge/physical notch.

NotchHub nên có:

```text
SwiftUI shadow
+
1 pt top seam mask
```

thay vì bật `panel.hasShadow`.

---

# 7. Khác biệt quan trọng giữa upstream và kiến trúc NotchHub

## 7.1 Boring Notch giữ host window lớn cố định

Upstream giữ native window `640 × 210` cả khi closed.

NotchHub architecture hiện quy định collapsed/hidden không được chặn interaction của app khác/menu bar bằng một transparent click-catching region lớn.

Vì vậy **không copy nguyên chiến lược fixed native host**.

NotchHub nên lấy phần tốt của upstream:

```text
persistent SwiftUI hierarchy
inner shape morph
fixed expanded visual size
```

nhưng dùng native host policy riêng:

```text
collapsed:
    small NSPanel host

opening:
    grow host envelope trước animation

expanded:
    host ~640 × 210

closing:
    giữ host lớn trong lúc visual Surface co lại

settled closed:
    shrink NSPanel về collapsed host
```

Đây là adaptation có chủ đích để thỏa `docs/architecture/notch-surface.md`.

---

## 7.2 Upstream dùng rectangular `contentShape`

Boring Notch hiện đặt `contentShape(Rectangle())` trên main layout.

Yêu cầu NotchHub của dự án này là touch view có bo/shape theo notch.

Do đó NotchHub **nên khác upstream ở điểm này**:

```text
rendered shape
= clipping shape
= SwiftUI interaction shape
```

Điều này giảm hover/click ở các góc transparent.

---

# 8. Target architecture sau refactor

```text
SurfaceCoordinator
    │
    ├── hover dwell / close grace / timeout
    ├── state machine intent
    │
    ▼
NotchPanelController
    │
    ├── sole NSPanel owner
    ├── native host envelope
    ├── event monitors
    │
    └── owns one persistent presentation model
             │
             ▼
       NSHostingView
             │
             ▼
     NotchSurfaceRootView
        │            │
        │            └── content slot
        │
        ├── NotchSurfaceShape
        ├── top seam
        ├── shadow
        └── NotchSurfaceTouchView
```

Không còn:

```text
state A -> destroy hosting root
state B -> create another hosting root
```

---

# 9. File mới

```text
Packages/NotchSurface/Sources/
├── NotchSurfaceMetrics.swift
├── NotchSurfaceShape.swift
├── NotchSurfaceTouchView.swift
├── NotchSurfacePresentationModel.swift
└── NotchSurfaceRootView.swift
```

Sửa:

```text
NotchSurfaceGeometry.swift
SurfaceCoordinator.swift
NotchPanelController.swift
Tests/NotchPackageSpineTests/NotchPackageSpineTests.swift
```

---

# 10. `NotchSurfaceMetrics.swift`

```swift
import CoreGraphics
import SwiftUI

enum NotchSurfaceMetrics {
    // Visible expanded Surface.
    static let expandedSurfaceSize = CGSize(width: 640, height: 190)

    // Native host envelope while expanded.
    static let expandedHostSize = CGSize(width: 640, height: 210)

    // No-notch fallback only.
    static let fallbackCollapsedSize = CGSize(width: 185, height: 32)

    static let closedTopShoulderRadius: CGFloat = 6
    static let closedBottomCornerRadius: CGFloat = 14

    static let openedTopShoulderRadius: CGFloat = 19
    static let openedBottomCornerRadius: CGFloat = 24

    static let hoverOpenDelay: Duration = .milliseconds(300)
    static let hoverCloseGrace: Duration = .milliseconds(100)

    static let openAnimation = Animation.spring(
        response: 0.42,
        dampingFraction: 0.80,
        blendDuration: 0
    )

    static let closeAnimation = Animation.spring(
        response: 0.45,
        dampingFraction: 1.00,
        blendDuration: 0
    )

    static let hoverAnimation = Animation.interactiveSpring(
        response: 0.38,
        dampingFraction: 0.80,
        blendDuration: 0
    )

    static let expandedContentDuration: TimeInterval = 0.35

    static let openTopPadding: CGFloat = 12
    static let openHorizontalPadding: CGFloat = 12

    static let shadowOpacity: Double = 0.70
    static let shadowRadius: CGFloat = 6

    // Must be tuned with native QA.
    static let closeHostSettleDelay: Duration = .milliseconds(500)
}
```

`closeHostSettleDelay` không phải giá trị upstream; đây là NotchHub adaptation để chờ SwiftUI close spring settle trước khi shrink native host.

---

# 11. Collapsed geometry

NotchHub hiện hard-code `136 × 46`.

Thay bằng display-derived geometry.

## 11.1 Physical notch

`NotchSurfaceGeometry` đã có `physicalNotchFrame`.

Thêm:

```swift
public static func collapsedSize(
    in topology: ScreenTopology
) -> CGSize?
```

Policy:

```text
valid physical notch:
    width  = physicalNotchFrame.width + small tolerance
    height = physicalNotchFrame.height

invalid / no notch:
    fallback 185 × 32
```

Pseudo-code clean-room:

```swift
public static func collapsedSize(
    in topology: ScreenTopology
) -> CGSize? {
    guard let screen = topology.screens.first(where: \.isBuiltIn) else {
        return nil
    }

    if let notch = screen.physicalNotchFrame,
       screen.frame.contains(notch),
       !notch.isEmpty {
        return CGSize(
            width: notch.width + 4,
            height: notch.height
        )
    }

    return NotchSurfaceMetrics.fallbackCollapsedSize
}
```

---

# 12. `NotchSurfaceShape.swift`

Không copy source `NotchShape.swift`.

Source upstream tự ghi provenance từ DynamicNotchKit, nên direct source reuse sẽ kéo thêm provenance/license review.

Triển khai clean-room theo behavioral geometry:

```swift
import SwiftUI

struct NotchSurfaceShape: Shape {
    var topShoulderRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get {
            .init(topShoulderRadius, bottomCornerRadius)
        }
        set {
            topShoulderRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let shoulder = min(
            max(topShoulderRadius, 0),
            rect.height * 0.45
        )

        let bottom = min(
            max(bottomCornerRadius, 0),
            rect.height * 0.45
        )

        let leftWall = rect.minX + shoulder
        let rightWall = rect.maxX - shoulder

        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Clean-room cubic shoulder. It produces the same visual property:
        // top outer edge transitions inward to an inset side wall.
        path.addCurve(
            to: CGPoint(x: leftWall, y: rect.minY + shoulder),
            control1: CGPoint(
                x: rect.minX + shoulder * 0.62,
                y: rect.minY
            ),
            control2: CGPoint(
                x: leftWall,
                y: rect.minY + shoulder * 0.38
            )
        )

        path.addLine(
            to: CGPoint(
                x: leftWall,
                y: rect.maxY - bottom
            )
        )

        path.addCurve(
            to: CGPoint(
                x: leftWall + bottom,
                y: rect.maxY
            ),
            control1: CGPoint(
                x: leftWall,
                y: rect.maxY - bottom * 0.30
            ),
            control2: CGPoint(
                x: leftWall + bottom * 0.30,
                y: rect.maxY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rightWall - bottom,
                y: rect.maxY
            )
        )

        path.addCurve(
            to: CGPoint(
                x: rightWall,
                y: rect.maxY - bottom
            ),
            control1: CGPoint(
                x: rightWall - bottom * 0.30,
                y: rect.maxY
            ),
            control2: CGPoint(
                x: rightWall,
                y: rect.maxY - bottom * 0.30
            )
        )

        path.addLine(
            to: CGPoint(
                x: rightWall,
                y: rect.minY + shoulder
            )
        )

        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: CGPoint(
                x: rightWall,
                y: rect.minY + shoulder * 0.38
            ),
            control2: CGPoint(
                x: rect.maxX - shoulder * 0.62,
                y: rect.minY
            )
        )

        path.closeSubpath()
        return path
    }
}
```

Điều cần match bằng visual QA không phải control-point tuyệt đối, mà là:

```text
top shoulder inset
bottom rounded corners
symmetry
top attachment
smooth radius morph
```

---

# 13. `NotchSurfaceTouchView`

```swift
struct NotchSurfaceTouchView<S: Shape>: View {
    let shape: S
    let onHoverChanged: (Bool) -> Void
    let onTap: () -> Void

    var body: some View {
        shape
            .fill(.clear)
            .contentShape(shape)
            .onHover(perform: onHoverChanged)
            .onTapGesture(perform: onTap)
    }
}
```

Không dùng:

```swift
.contentShape(Rectangle())
```

cho Surface mới.

---

# 14. Presentation model

```swift
@MainActor
@Observable
final class NotchSurfacePresentationModel {
    private(set) var snapshot = SurfaceSnapshot()
    var collapsedSize = NotchSurfaceMetrics.fallbackCollapsedSize
    var isHovering = false

    func apply(_ snapshot: SurfaceSnapshot) {
        self.snapshot = snapshot
    }

    var visibleSurfaceSize: CGSize {
        switch snapshot.state {
        case .expanded:
            NotchSurfaceMetrics.expandedSurfaceSize
        case .compact:
            CGSize(width: 220, height: 52)
        default:
            collapsedSize
        }
    }

    var topShoulderRadius: CGFloat {
        snapshot.state == .expanded
            ? NotchSurfaceMetrics.openedTopShoulderRadius
            : NotchSurfaceMetrics.closedTopShoulderRadius
    }

    var bottomCornerRadius: CGFloat {
        snapshot.state == .expanded
            ? NotchSurfaceMetrics.openedBottomCornerRadius
            : NotchSurfaceMetrics.closedBottomCornerRadius
    }
}
```

`SurfaceCoordinator.snapshot` là nguồn chân lý duy nhất cho `SurfaceState`.
Presentation model chỉ cache snapshot đã nhận cùng geometry/animation transient; view không
được mutate state và native apply failure phải quay về coordinator để đi recovery.

---

# 15. Root view

```swift
struct NotchSurfaceRootView: View {
    @Bindable var model: NotchSurfacePresentationModel

    let send: (SurfaceIntent) -> Void
    let openDetail: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var isExpanded: Bool {
        model.snapshot.state == .expanded
    }

    var body: some View {
        let shape = NotchSurfaceShape(
            topShoulderRadius: model.topShoulderRadius,
            bottomCornerRadius: model.bottomCornerRadius
        )

        ZStack(alignment: .top) {
            shape
                .fill(.black)

            if isExpanded {
                ExpandedSurfaceContent(openDetail: openDetail)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(
                        .scale(scale: 0.8, anchor: .top)
                            .combined(with: .opacity)
                    )
            }

            // Prevent a light anti-alias seam against the screen/notch.
            Rectangle()
                .fill(.black)
                .frame(height: 1)
                .padding(.horizontal, model.topShoulderRadius)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(
            width: model.visibleSurfaceSize.width,
            height: model.visibleSurfaceSize.height,
            alignment: .top
        )
        .clipShape(shape)
        .overlay {
            NotchSurfaceTouchView(
                shape: shape,
                onHoverChanged: handleHover,
                onTap: { send(.clicked) }
            )
        }
        .shadow(
            color: (isExpanded || model.isHovering)
                ? .black.opacity(NotchSurfaceMetrics.shadowOpacity)
                : .clear,
            radius: NotchSurfaceMetrics.shadowRadius
        )
        .animation(
            surfaceAnimation,
            value: model.snapshot.state
        )
    }

    private var surfaceAnimation: Animation {
        if reduceMotion {
            return .easeOut(duration: 0.12)
        }

        return isExpanded
            ? NotchSurfaceMetrics.openAnimation
            : NotchSurfaceMetrics.closeAnimation
    }

    private func handleHover(_ hovering: Bool) {
        model.isHovering = hovering

        if isExpanded {
            send(
                hovering
                    ? .expandedHoverEntered
                    : .expandedHoverExited
            )
        } else {
            send(
                hovering
                    ? .hoverEntered
                    : .hoverExited
            )
        }
    }
}
```

Expanded child nên có thêm:

```swift
.animation(
    .smooth(duration: 0.35),
    value: isExpanded
)
```

hoặc transition animation tương đương.

---

# 16. Refactor `NotchPanelController`

## 16.1 Vấn đề hiện tại

Hiện controller làm:

```text
showCollapsed
 -> setFrame(136×46)
 -> create NSHostingView(CollapsedNotchSurfaceView)

showExpanded
 -> setFrame(320×160)
 -> create NSHostingView(ExpandedNotchSurfaceView)
```

Đây là blocker lớn nhất đối với Boring-style morph.

## 16.2 Target

Controller chỉ tạo:

```text
one NSPanel
one NSHostingView
one NotchSurfacePresentationModel
```

trong lifecycle bình thường.

Properties:

```swift
private var panel: NSPanel?
private var hostingView: NSHostingView<NotchSurfaceRootView>?

private let presentationModel =
    NotchSurfacePresentationModel()

private var closeHostSettleTask: Task<Void, Never>?
```

---

# 17. Opening sequence

Boring Notch có sẵn host lớn, nên inner Surface có đủ canvas để grow.

NotchHub host collapsed lại nhỏ để tránh click interception. Vì vậy opening phải có một **prepare-host phase**:

```text
collapsed host
    ↓
cancel pending close-host task
    ↓
resize transparent host → 640 × 210
    ↓
keep visible shape collapsed and top-centered
    ↓ next main run-loop
presentationModel.state = expanded
    ↓
SwiftUI morph:
- size -> 640 × 190
- top shoulder 6 -> 19
- bottom radius 14 -> 24
- child content scale/opacity
```

Pseudo-code:

```swift
private func showExpanded(focus: Bool) -> Bool {
    closeHostSettleTask?.cancel()
    closeHostSettleTask = nil

    let panel = ensurePanel()

    guard let frame = surfaceFrame(
        for: NotchSurfaceMetrics.expandedHostSize
    ) else {
        return false
    }

    updateCollapsedMetricsIfNeeded()

    panel.setFrame(frame, display: false)
    panel.orderFrontRegardless()

    Task { @MainActor [weak self] in
        guard let self else { return }
        self.presentationModel.state = .expanded
    }

    installExpandedEventMonitors()

    if focus {
        priorKeyWindow = NSApp.keyWindow
        panel.makeKeyAndOrderFront(nil)
    }

    return true
}
```

Root view phải top-center align visible Surface trong host.

---

# 18. Closing sequence

```text
expanded
    ↓
presentationModel.state = collapsed
    ↓
close spring runs inside large host
    ↓
wait for spring settle
    ↓
if still collapsed
    ↓
shrink native host to collapsed frame
```

Pseudo-code:

```swift
private func showCollapsed() -> Bool {
    removeEventMonitors()

    let panel = ensurePanel()

    presentationModel.state = .collapsed

    closeHostSettleTask?.cancel()
    closeHostSettleTask = Task { @MainActor [weak self, weak panel] in
        try? await Task.sleep(
            for: NotchSurfaceMetrics.closeHostSettleDelay
        )

        guard
            let self,
            let panel,
            !Task.isCancelled,
            self.presentationModel.state == .collapsed,
            let collapsedSize = self.currentCollapsedHostSize(),
            let frame = self.surfaceFrame(for: collapsedSize)
        else {
            return
        }

        panel.setFrame(frame, display: false)
    }

    panel.orderFrontRegardless()
    return true
}
```

### Race condition bắt buộc phải test

```text
start closing
 -> closeHostSettleTask scheduled
 -> pointer re-enters
 -> open again
 -> OLD task fires
 -> host shrinks unexpectedly
```

Mọi open path phải cancel task này.

---

# 19. `SurfaceCoordinator` hover policy

## 19.1 Config

```swift
public struct SurfaceInteractionConfiguration: Equatable, Sendable {
    public let hoverDelay: Duration
    public let hoverExitGrace: Duration
    public let autoCollapseDelay: Duration
}
```

Default:

```text
hoverDelay        = 300 ms
hoverExitGrace    = 100 ms
autoCollapseDelay = 3 s
```

`3 s` là policy F2 hiện tại của NotchHub; upstream Boring Notch hover exit đóng nhanh hơn. Giữ 3 s như fallback cho các open path không đến từ hover.

---

## 19.2 Track expansion origin — NotchHub adaptation

Boring Notch không có explicit typed expansion-origin state.

NotchHub nên có để không phá interaction contract hiện tại:

```swift
private enum ExpansionOrigin {
    case hover
    case click
}
```

Khi `.hoverDelayElapsed` gây open:

```text
origin = hover
```

Khi `.clicked` gây open:

```text
origin = click
```

---

## 19.3 Hover exit

```swift
case .expandedHoverExited
    where snapshot.state == .expanded:

    isHoveringExpanded = false

    if expansionOrigin == .hover, interactionHolds.isEmpty {
        scheduleHoverCollapse()
    } else {
        cancelHoverCollapse()
        if expansionOrigin != .hover {
            scheduleAutoCollapse()
        }
    }
```

Hover collapse scheduler:

```swift
private func scheduleHoverCollapse() {
    cancelHoverCollapse()

    hoverCollapseGeneration += 1
    let generation = hoverCollapseGeneration

    hoverCollapseTask = scheduler.schedule(
        after: configuration.hoverExitGrace
    ) { [weak self] in
        guard
            let self,
            self.hoverCollapseGeneration == generation
        else {
            return
        }

        self.hoverCollapseTask = nil
        _ = self.handle(.hoverExitGraceElapsed)
    }
}
```

Re-entry:

```swift
case .expandedHoverEntered
    where snapshot.state == .expanded:

    isHoveringExpanded = true
    cancelHoverCollapse()
    cancelAutoCollapse()
```

`SurfaceCoordinator` sở hữu interaction-hold registry theo expanded interaction session. Khi
hold cuối cùng được release và pointer vẫn outside, registry schedule lại grace từ đầu; mọi
transition ra khỏi `.expanded` clear registry, cancel grace và invalidate stale lease generation.

---

# 20. State-machine intent mới

Thêm:

```swift
case hoverExitGraceElapsed
```

Transition:

```swift
case (.expanded, .hoverExitGraceElapsed):
    (.collapsed, .showCollapsed)
```

Clear expansion origin khi final state không còn expanded.

---

# 21. Compact state

Giữ `compact = 220 × 52` của F2 hiện tại.

Không đưa Compact vào Boring parity PR ngoài việc:

- render qua persistent root;
- dùng cùng shape infrastructure;
- không làm regression timeout/state-machine.

Có thể dùng intermediate radius riêng sau; chưa cần ở PR đầu.

---

# 22. Fixed Surface nghĩa là gì

“Fixed Surface 640 × 190” nghĩa là:

```text
visible Surface geometry = 640 × 190
```

Không có nghĩa child content được phép resize native panel.

Feature/module content phải render bên trong slot:

```swift
.frame(
    width: 640,
    height: 190
)
```

Media/Xiaozhi/Shelf sau này chỉ thay content.

Không làm:

```text
Text intrinsic size
 -> Surface intrinsic size
 -> panel resize
```

Trước mọi transition sang `.expanded`, coordinator phải admission native host
`640 × 210` vào safe geometry của built-in display/top-center fallback. Không được scale,
crop hay chọn kích thước expanded khác. Topology hợp lệ nhưng không chứa vừa là capability
unavailable: giữ `collapsed` hoặc phản hồi explicit request bằng `compact`; hover không mở
Detail. Chỉ invalid topology hoặc native apply failure mới đi recovery.

---

# 23. Collapsed production content

Bỏ:

```text
Text("NotchHub")
```

khỏi normal collapsed rendering.

Collapsed state theo architecture hiện tại chỉ nên có:

- black physical-notch extension;
- hoặc tiny status glyph/dot nếu sau này Presentation Policy yêu cầu.

Debug label chỉ xuất hiện khi F2 debug overlay bật.

---

# 24. Hit testing

## SwiftUI level

Dùng exact `NotchSurfaceShape` làm `contentShape`.

## NSPanel level

SwiftUI `contentShape` không thay đổi hit region của native window bên ngoài content.

Do đó `NotchPanelController` phải sở hữu `SurfacePointerMonitor`, theo dõi mouse move local
và global độc lập với `.onHover`, rồi so `NSEvent.mouseLocation` với geometry screen-space của
visible `NotchSurfaceShape`. Khi pointer ở ngoài shape — gồm transparent corner và shadow
envelope — controller đặt `NSPanel.ignoresMouseEvents = true`; khi pointer vào shape thì bật lại.
Native mouse-capture lease là ngoại lệ duy nhất. Recompute phải chạy đồng bộ sau mọi thay đổi
geometry/state/capture, không chờ mouse move kế tiếp.

Host lifecycle vẫn phải:

```text
collapsed -> small host
expanded  -> large host
```

Không giữ transparent host lớn sau khi close settle.

---

# 25. Focus policy

Boring Notch window không trở thành key/main.

NotchHub hiện có click-open path có thể gọi `makeKeyAndOrderFront` để hỗ trợ Escape/focus interaction.

Không thay đổi phần này chỉ để “giống Boring Notch”.

Boring parity ở PR này là:

```text
shape
geometry
hover timing
animation
visual attachment
```

Focus policy tiếp tục theo F2 NotchHub.

---

# 26. Reduced Motion

```swift
@Environment(\.accessibilityReduceMotion)
```

Policy:

```text
Reduce Motion off:
    open 0.42 / 0.80 spring
    close 0.45 / 1.00 spring
    child 0.8 top-scale + opacity

Reduce Motion on:
    short ~0.12 s ease-out
    no spring overshoot
```

State/timers vẫn hoạt động như bình thường.

---

# 27. Test plan

## 27.1 Sizing

Thêm:

```text
physical notch -> collapsed size derived from physical notch
no-notch       -> 185 × 32 fallback
expanded visual Surface == 640 × 190
expanded host envelope  == 640 × 210
```

---

## 27.2 Hover dwell

Default test:

```text
showCollapsed
hoverEntered
299 ms -> still collapsed
300 ms -> expanded
```

Scheduler test không cần wall-clock; dùng injected scheduler.

---

## 27.3 Exit grace

```text
expanded from hover
expandedHoverExited
 -> schedule 100 ms

before timer:
state == expanded

timer fires:
state == collapsed
```

---

## 27.4 Re-entry cancellation

```text
hover-open
exit
schedule close A
re-enter
cancel A
fire stale A
expect expanded
```

---

## 27.5 Native host race

Controller-level/manual:

```text
expanded
close starts
re-open before settle
old host-shrink task must not shrink panel
```

---

## 27.6 Click-open policy

```text
clicked -> expanded(origin=click)
expandedHoverExited
 -> no 100 ms hover collapse
 -> use existing inactivity policy
```

---

## 27.7 Existing F2 regressions

Giữ pass:

- Escape;
- click outside;
- 3 s auto-collapse;
- full-screen suppression;
- Space changes;
- sleep/wake;
- lock/unlock;
- display invalidation/recovery;
- built-in display selection;
- no-notch fallback.

---

# 28. Manual visual QA

## Shape

Expanded `640 × 190` phải nhìn:

```text
screen edge
──────────────────────────────────────

┐                                    ┌
 ╲                                  ╱
  │                                │
  │                                │
  │                                │
   ╲                              ╱
    ╰────────────────────────────╯
```

Không được trông như:

```text
╭──────────────────────────────────╮
│                                  │
╰──────────────────────────────────╯
```

Check:

- side wall inset rõ ở top;
- bottom radius lớn hơn top shoulder;
- trái/phải symmetry;
- không có white/transparent seam 1 px ở top;
- black fill nối liền physical notch.

---

## Open

- hover ~300 ms mới mở;
- không có frame jump;
- không swap đột ngột từ tiny capsule sang rectangle;
- final visible size `640 × 190`;
- top shoulder morph `6 -> 19`;
- bottom corner morph `14 -> 24`;
- child content scale từ `.top`;
- shadow hiện ra tự nhiên.

---

## Close

- exit không đóng ngay;
- khoảng 100 ms grace;
- re-enter trong grace giữ open;
- close damping gọn, không bounce;
- native host chỉ shrink sau khi visual close đã gần hoàn tất.

---

# 29. Thứ tự implementation

```text
1. NotchSurfaceMetrics.swift
2. NotchSurfaceShape.swift
3. geometry tests cho shape metrics / Surface sizes
4. NotchSurfaceTouchView.swift
5. NotchSurfacePresentationModel.swift
6. NotchSurfaceRootView.swift
7. refactor NotchPanelController sang persistent hosting root
8. add prepare-open / settle-close host phases
9. update SurfaceCoordinator hover delay + close grace
10. add expansion origin
11. update state-machine tests
12. native visual QA
13. update F2 evidence
```

Không nên bắt đầu bằng media/Xiaozhi content.

---

# 30. Definition of Done

```text
[ ] collapsed không còn Capsule + "NotchHub"
[ ] collapsed size derive từ physical notch
[ ] no-notch fallback vẫn an toàn
[ ] expanded visible Surface cố định 640 × 190
[ ] expanded host có đủ room cho shadow
[ ] custom NotchSurfaceShape có inset top shoulder
[ ] closed radii 6 / 14
[ ] opened radii 19 / 24
[ ] radii là animatable data
[ ] one persistent hosting root
[ ] hover dwell default 300 ms
[ ] hover exit grace 100 ms
[ ] re-enter cancel pending close
[ ] open spring 0.42 / 0.80
[ ] close spring 0.45 / 1.00
[ ] expanded child transition scale 0.8 from top + opacity
[ ] SwiftUI shadow ~0.7 / radius 6
[ ] 1 pt black top seam treatment
[ ] touch shape dùng notch shape, không Rectangle
[ ] native click-through ngoài visible shape được kiểm chứng cả khi panel đã ignore mouse events
[ ] collapsed native host không giữ transparent 640 × 210
[ ] stale close-host task không resize panel đã reopen
[ ] Escape/click-outside/recovery F2 không regression
[ ] Reduced Motion pass
[ ] keyboard focus, VoiceOver, focus restoration và collapsed/suppressed pass accessibility gate
[ ] physical-notch manual QA pass
```

---

# 31. Những điểm KHÔNG copy từ Boring Notch

Do khác biệt kiến trúc và licensing/provenance:

```text
Không copy source NotchShape.swift.
Không copy exact Path implementation.
Không copy private SkyLight usage.
Không giữ native window lớn cố định khi collapsed.
Không copy feature-specific battery/share state vào core Surface.
Không thay F2 lifecycle/recovery bằng upstream architecture.
```

Đặc biệt `NotchShape.swift` upstream có attribution tới DynamicNotchKit, nên direct reuse cần review provenance/license riêng.

NotchHub chỉ học:

```text
behavior
measurements
timing
shape properties
animation composition
```

rồi implement clean-room trong architecture hiện tại.

---

# 32. Source map đã kiểm tra

## Boring Notch

- `boringNotch/sizing/matters.swift`
  - `openNotchSize`
  - `windowSize`
  - open/closed corner values
  - closed display-derived sizing

- `boringNotch/components/Notch/NotchShape.swift`
  - separate top/bottom radii
  - animatable radii
  - inset shoulder silhouette
  - provenance note

- `boringNotch/ContentView.swift`
  - clipped black notch shape
  - open/close spring
  - hover handler
  - 100 ms exit grace
  - content transition
  - shadow
  - top seam strip
  - stable window-sized SwiftUI root

- `boringNotch/models/BoringViewModel.swift`
  - `open()` sets fixed open size/state
  - `close()` restores calculated closed size/state

- `boringNotch/models/Constants.swift`
  - default hover duration `0.3`
  - open-on-hover setting
  - shadow and radius scaling settings

- `boringNotch/boringNotchApp.swift`
  - creates one top-centered `640 × 210` window host
  - attaches one `NSHostingView`
  - uses fixed host envelope

- `boringNotch/components/Notch/BoringNotchWindow.swift`
  - transparent floating panel properties

## NotchHub `dev`

- `Packages/NotchSurface/Sources/NotchPanelController.swift`
- `Packages/NotchSurface/Sources/SurfaceCoordinator.swift`
- `Packages/NotchSurface/Sources/NotchSurfaceGeometry.swift`
- `Tests/NotchPackageSpineTests/NotchPackageSpineTests.swift`
- `docs/architecture/notch-surface.md`

---

# 33. PR boundary đề xuất

```text
feat(surface): add Boring-inspired animated notch geometry
```

PR chỉ gồm:

- geometry/radius;
- persistent root;
- hover open/exit timing;
- fixed expanded Surface;
- host preparation/settle;
- shape hit testing;
- tests;
- F2 evidence update.

Không trộn:

- media UI;
- shelf;
- Xiaozhi;
- module runtime;
- Actions;
- IPC;
- Settings.

Đây là một visual/interaction primitive của `NotchSurface`, không phải feature module.

---

# 34. Contract đã xác nhận sau grilling

## 34.1 Hover và interaction hold

- Hover dwell mặc định là `300 ms`.
- Grace `100 ms` chỉ schedule khi state là `expanded`, origin là `hover`, pointer đã rời
  Surface và expanded interaction session không có `SurfaceInteractionHold` active.
- Hold lease có type, thuộc session generation hiện tại và được coordinator sở hữu. Keyboard
  focus, popover, drag/gesture, confirmation và accessibility interaction đều acquire/release
  lease qua adapter; stale release bị bỏ qua.
- Mọi authoritative transition rời `.expanded` invalidates session, clear hold, cancel hover-close
  và invalidates token. Khi hold cuối cùng kết thúc, pointer vẫn ngoài thì grace bắt đầu lại từ đầu.

## 34.2 State, admission và capability

- `SurfaceCoordinator.snapshot` là authoritative presentation state; presentation model chỉ là
  projection render. Native apply failure phải được trả về coordinator để recovery.
- `640 × 190` visual và `640 × 210` host là fixed contract. Admission không được tự scale/crop.
- `expandedAvailability` chỉ mô tả topology đã validate hiện hành và mang `topologyRevision`.
  Invalidation geometry làm capability cũ hết hiệu lực trước revalidation.
- Admission rejection là feedback tạm thời của request/topology revision, không phải recovery
  state. Hover rejection silent UI; click/keyboard rejection có accessible feedback bounded.
  Feedback bị clear khi topology đổi, admission thành công, recovery/suppression hoặc hết hạn;
  lịch sử thuộc bounded Diagnostics event history.

## 34.3 Native input và accessibility

- `contentShape` chỉ điều phối SwiftUI gesture; native click-through bắt buộc do controller
  quản lý bằng `SurfacePointerMonitor` và `NSPanel.ignoresMouseEvents` theo visible shape.
- Boring-style parity chưa hoàn tất nếu Surface steal focus, VoiceOver còn ở collapsed view,
  Escape hỏng, hoặc host collapsed/suppressed chặn tương tác của app khác.
