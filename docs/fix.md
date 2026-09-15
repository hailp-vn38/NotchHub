Tôi đã kiểm tra `dev` hiện tại của NotchHub tại commit `81eb5a75...` và đối chiếu flow tương tác của `TheBoredTeam/boring.notch`.  Kết luận chính là: **2 lỗi bạn mô tả có cùng một gốc: NotchHub đang trộn hover-state, presentation-state và window-focus vào cùng flow transition; Boring Notch tách ba thứ này khá rõ.**

Điều này cũng phù hợp với boundary kiến trúc của NotchHub: `NotchSurface` là nơi sở hữu `NSPanel`, interaction state machine và hit-testing.

## Flow của Boring Notch

Boring Notch giữ flow tương đối đơn giản:

```text
Pointer
   │
   ├── enter
   │     ├─ cancel pending hover task
   │     ├─ isHovering = true
   │     └─ nếu state == closed
   │           ↓ 300 ms
   │        kiểm tra LẠI:
   │        state == closed && isHovering
   │           ↓
   │         open()
   │
   └── exit
         ├─ cancel pending hover task
         └─ delay 100 ms
                ↓
          kiểm tra LẠI:
          state == open
          && không có popover/share giữ notch
                ↓
              close()
```

`minimumHoverDuration` mặc định của Boring là `0.3s`.  Hover được xử lý bằng **một `isHovering` duy nhất**, một `hoverTask` có thể cancel, và task delayed open còn re-check điều kiện trước khi thực sự gọi open.

Điểm rất quan trọng khác: `ContentView` chỉ animate theo `vm.notchState`; tap gọi `doOpen()`, còn `open()` chỉ đặt lại `notchSize` và `notchState = .open`. Nếu notch đã `.open`, giá trị điều khiển animation không đổi nên không tạo một transition open mới.

Nhưng khác biệt lớn nhất liên quan trực tiếp lỗi số 2 là window:

```swift
override var canBecomeKey: Bool { false }
override var canBecomeMain: Bool { false }
```

Boring Notch dùng `NSPanel` không thể trở thành key/main window.  Khi tạo window, nó còn dùng `.nonactivatingPanel`.

Tức là click vào notch **không giành focus từ Terminal/Xcode/Safari đang active**. Đây là khác biệt rất lớn với NotchHub hiện tại.

---

# 1. Vì sao NotchHub thỉnh thoảng chạy lại animation open khi đang expanded?

Sau bản sửa, `SurfaceStateMachine` có hợp đồng:

```text
collapsed + clicked -> không có transition
compact   + clicked -> expanded

expanded + clicked -> không có transition
```

Nhánh cũ `collapsed + clicked -> expanded` là nguyên nhân trực tiếp khiến một click lọt vào sau vài chu kỳ có thể phát lại animation mở. Surface collapsed giờ chỉ mở bằng hover dwell hoặc đường bàn phím; click bên trong Surface đã mở chỉ chuyển interaction sang deliberate mà không phát lại transition mở.

Vì vậy lỗi bạn thấy nhiều khả năng không phải:

```text
expanded
   └─ click
       └─ expanded lại
```

mà thực tế là race kiểu:

```text
expanded
   │
   ├─ hover event / close grace
   │       ↓
   │   collapsed
   │       ↓
   └─ click vừa xảy ra
           ↓
        expanded
```

Người dùng nhìn thấy nó giống như animation open bị chạy lại.

### Điểm đáng nghi nhất trong code

Trong `NotchSurfacePresentation.swift`:

```swift
.onHover(perform: handleHover)
.onTapGesture { send(.clicked) }
```

và:

```swift
private func handleHover(_ hovering: Bool) {
    model.isHovering = hovering

    send(
        hovering
            ? (isExpanded ? .expandedHoverEntered : .hoverEntered)
            : (isExpanded ? .expandedHoverExited : .hoverExited)
    )
}
```

Ở đây **ý nghĩa của mouse event phụ thuộc vào `isExpanded` của geometry tại thời điểm callback chạy**.

Trong lúc notch animate:

```text
collapsed shape
       ↓
expanded shape
```

hit region của SwiftUI cũng thay đổi kích thước. Con trỏ có thể đứng yên nhưng boundary của view đang chạy qua con trỏ. SwiftUI có thể sinh enter/exit khi geometry thay đổi.

Do đó có khả năng xảy ra:

```text
pointer vẫn đứng trong vùng notch

projectExpanded()
       ↓
shape thay đổi
       ↓
SwiftUI onHover exit/enter
       ↓
event được phân loại dựa trên isExpanded hiện tại
       ↓
expandedHoverExited
       ↓
scheduleCloseForCurrentOrigin()
```

Sau đó click đúng lúc grace timer chạy → collapse → click → open lại.

### Boring tránh điểm này thế nào?

Boring không có hai semantic:

```text
hoverEntered
expandedHoverEntered
```

Nó chỉ có:

```text
isHovering = true / false
```

State của notch được kiểm tra **sau đó**, không dùng state để định nghĩa loại hover event.

Đây là khác biệt kiến trúc quan trọng.

---

# 2. Vì sao click Surface → move ra ngoài → focus window khác thì mất collapse animation?

Đây là chỗ khác biệt với Boring Notch rõ nhất.

Flow đúng bắt đầu bằng hover rồi mới click Surface đang mở:

```text
Terminal đang key
      ↓
hover NotchHub đủ dwell
      ↓
Surface expanded không giành key window
      ↓
click Surface đang mở
      ↓
move chuột ra
      ↓
click Terminal
      ↓
NotchHub global mouse monitor nhận clickedOutside
+
NotchHub defer collapse sang lượt MainActor kế tiếp
+
SwiftUI nhận transition và chạy animation đóng
```

`installExpandedEventMonitors()` bắt cả local và global `leftMouseDown`, nhưng cả hai monitor phải tái dùng native shape hit-test trước khi gửi `.clickedOutside`; nếu không, click bên trong Surface mở có thể bị phân loại nhầm là outside và đóng ngay.

Focus restoration vẫn là trách nhiệm của native owner khi có một đường mở thực sự yêu cầu focus:

`showCollapsed()` có:

```swift
panel.resignKey()
priorKeyWindow?.makeKeyAndOrderFront(nil)
priorKeyWindow = nil
```

Trong khi `SurfaceCoordinator.apply()` khi rời expanded cũng gọi:

```swift
restoreFocusAfterSurfaceInteraction()
```

Nguyên nhân của hiện tượng được tái hiện là `.clickedOutside` từng apply collapse đồng bộ ngay trong callback mouse-down, khiến SwiftUI không có một render turn ổn định để bắt đầu animation:

> click window khác → Surface snap về collapsed nhưng animation collapse không còn được nhìn thấy.

Boring Notch tránh toàn bộ class lỗi này bằng cách **không cho notch panel trở thành key ngay từ đầu**:

```text
External window remains key
         │
         ├── hover notch → open
         ├── click notch
         ├── move outside → close animation
         │
         └── click external window
                  ↓
        không cần restore focus
```

Window của Boring là `.nonactivatingPanel`, `canBecomeKey == false` và `canBecomeMain == false`.

---

# Flow tôi đề xuất cho NotchHub

Không nên copy nguyên code Boring; nên lấy **interaction model** của nó và giữ state-machine architecture của NotchHub.

```text
                       ┌───────────────────┐
pointer enter ────────►│ pointerInside=true│
                       └─────────┬─────────┘
                                 │
                      state == collapsed ?
                                 │ yes
                                 ▼
                        schedule expand 300ms
                                 │
                      revalidate condition
                state == collapsed && pointerInside
                                 │
                                 ▼
                              expand


pointer exit ─────────► pointerInside=false
                                 │
                                 ▼
                         schedule close 100ms
                                 │
                        revalidate condition
              state == expanded && !pointerInside
                    && interactionHolds.empty
                                 │
                                 ▼
                              collapse
```

### Thay đổi quan trọng nhất

Thay:

```swift
.hoverEntered
.hoverExited
.expandedHoverEntered
.expandedHoverExited
```

bằng semantic trung lập:

```swift
.hoverChanged(Bool)
```

Coordinator mới là nơi quyết định:

```swift
if pointerInside {
    switch state {
    case .collapsed:
        scheduleExpansion()
    case .expanded:
        cancelCollapse()
    ...
    }
}
```

Như vậy geometry animation không thể làm một hover event bị "đổi nghĩa".

---

## Click cũng cần idempotent

Tôi sẽ đổi flow thành:

```swift
case .primaryActivated:
    guard snapshot.state != .expanded else {
        registerInteraction()
        return snapshot.state
    }

    requestExpansion(...)
```

Và tốt hơn nữa có transition phase:

```swift
enum SurfaceTransitionPhase {
    case idle
    case expanding
    case collapsing
}
```

Khi đang:

```text
.expanding
```

mọi request expand mới là no-op.

Khi đang:

```text
.collapsing
```

một click cũ/stale không được tự động tạo `collapsed -> expanded` trừ khi xác nhận đó là một interaction mới hợp lệ.

---

# Với focus, tôi đề xuất thay đổi mạnh hơn

Đối với Surface bình thường:

```swift
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

và style:

```swift
[
    .borderless,
    .nonactivatingPanel
]
```

Normal click:

```text
showExpanded(focus: false)
```

không dùng:

```swift
makeKeyAndOrderFront()
```

Đây là flow gần với Boring nhất và sẽ loại bỏ phần lớn lỗi số 2.

Nếu sau này module Xiaozhi/clipboard cần `TextField`, keyboard navigation hoặc control thực sự cần key window, hãy có **explicit focus lease** riêng:

```text
normal surface interaction
        │
        └── non-activating

user explicitly enters keyboard editing
        │
        └── acquireKeyboardFocus()
                 ↓
           focus lease
                 ↓
             edit...
                 ↓
           release focus
```

Không nên biến **mọi click trên expanded Surface** thành `focus:true`.

---

# Thứ tự fix tôi khuyến nghị

| Priority | Thay đổi                                                  | Xử lý                      |
| -------- | --------------------------------------------------------- | -------------------------- |
| **P0**   | `hoverChanged(Bool)` + pointer truth độc lập geometry     | Lỗi reopen animation       |
| **P0**   | Surface bình thường thành non-activating / non-key        | Lỗi mất collapse animation |
| **P0**   | Click khi expanded = interaction/no-op                    | chống reopen               |
| **P1**   | chỉ một owner chịu trách nhiệm restore focus              | loại race AppKit           |
| **P1**   | collapse/expand request idempotent                        | chống duplicate event      |
| **P1**   | outside-click chỉ là fallback, không phải focus mechanism | ổn định transition         |
| **P2**   | explicit focus lease cho control cần keyboard             | chuẩn bị cho modules       |

Đặc biệt tôi sẽ **bỏ việc restore focus ở cả `showCollapsed()` lẫn `SurfaceCoordinator` cùng lúc**. Focus lifecycle phải có đúng một owner.

---

## Các regression test nên thêm

Tối thiểu cần khóa 6 case này:

```text
1. expanded -> click inside x100
   => showExpanded chỉ xảy ra một lần

2. hover expand -> synthetic hover events do resize
   => không collapse/re-open

3. hover exit -> re-enter trong 100ms
   => close task bị cancel

4. expanded -> pointer exit -> click Terminal
   => chỉ một expanded -> collapsed transition

5. collapse đang animate -> external window becomes key
   => animation target vẫn collapsed, không snap

6. local + global outside mouse-down cùng phát
   => collapse request được coalesce thành một transition
```

### Chốt

Hai điểm từ Boring Notch đáng áp dụng nhất không phải spring parameters mà là:

**(1)** hover là một boolean độc lập với open/closed geometry, delayed action luôn re-check state trước khi commit;
**(2)** notch panel là một **non-activating surface**, không giành key-window focus trong normal interaction.

NotchHub hiện tại đã có state machine tốt hơn Boring ở nhiều mặt, nên tôi **không khuyến nghị thay kiến trúc bằng flow của Boring**. Tôi khuyến nghị giữ `SurfaceCoordinator`, nhưng sửa input/focus layer theo flow trên. Điều đó xử lý đúng cả hai lỗi mà không phá foundation architecture.
