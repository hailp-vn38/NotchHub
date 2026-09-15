# F5 Permission Center

**Status:** ready-for-human
**Phase:** F5
**Owner:** Platform / Security / UX

## Problem Statement

NotchHub có Settings shell và một glossary cho **Capability**, nhưng chưa có một owner chạy được
cho trạng thái permission, request theo ngữ cảnh, hoặc recovery sau khi người dùng từ chối hay
thu hồi quyền trong System Settings. Nếu mỗi feature, view, hoặc Module sau này tự gọi API macOS,
app sẽ tạo prompt không nhất quán, không thể kiểm chứng chính sách no-prompt-at-launch, và dễ vượt
qua trust boundary đã được chấp nhận trong ADR-0008.

F5 cần đưa Permission Center thành capability owner có thể kiểm chứng mà không kéo Shortcut,
Action, Module runtime, event delivery, hoặc Diagnostics retention vào sớm. Bằng chứng dọc thực
tế duy nhất của F5 là Notifications, dùng cho recovery notification do người dùng chủ động opt in.

## Solution

Xây dựng một **PermissionCoordinator** làm seam duy nhất cho Permission Center. Coordinator sở
hữu capability metadata, status projection, validation của request context, pre-permission flow,
deduplication, System Settings recovery, refresh khi app active, và audit metadata đã sanitize.
UI Permissions chỉ render projection và gửi explicit user intent; không gọi privacy API trực tiếp.

F5 chỉ có adapter/request path thật cho Notifications. Người dùng phải bấm một recovery-notification
opt-in cụ thể, đọc explanation, rồi xác nhận trước khi coordinator có thể gọi system prompt. Quyền
được cấp chỉ cho phép recovery notification thuộc Permission Center; F5 không tạo delivery policy
chung, notification từ Action/Module, hay persistent preference mới ngoài trạng thái authorization
do macOS sở hữu. Accessibility được giữ cho F6 nếu shortcut design được chọn thực sự cần nó. Các
capability còn lại là informational future capability, không được prompt hay giả lập là đã có owner.

## User Stories

1. Là người dùng NotchHub, tôi muốn mở Permissions trong Settings mà không thấy system prompt, để tôi có thể hiểu quyền riêng tư trước khi chọn dùng tính năng.
2. Là người dùng, tôi muốn biết Notifications phục vụ recovery notification nào, để consent của tôi có lý do cụ thể thay vì là một yêu cầu mơ hồ.
3. Là người dùng, tôi muốn thấy pre-permission explanation trước khi macOS hỏi, để tôi có thể quyết định có cấp quyền hay không.
4. Là người dùng, tôi muốn chỉ thấy prompt Notifications sau khi tự bấm và xác nhận recovery opt-in, để app không xin quyền ngoài ý muốn.
5. Là người dùng từ chối Notifications, tôi muốn Permissions vẫn sử dụng được và mô tả rõ tác động, để từ chối không làm app trông như bị hỏng.
6. Là người dùng đã từ chối quyền, tôi muốn có nút Open System Settings phù hợp, để tôi có đường recovery rõ ràng mà không bị prompt lặp lại.
7. Là người dùng cấp lại hoặc thu hồi quyền trong System Settings, tôi muốn status đổi khi quay về app, để UI không hiển thị trạng thái cũ.
8. Là người dùng, tôi muốn capability chưa được feature nào dùng được ghi là not used, để tôi không nhầm một capability tương lai với permission bị thiếu.
9. Là người dùng, tôi muốn Microphone, Camera, Calendar, Reminders, Screen Recording, Automation và Accessibility không tự prompt trong F5, để Permission Center không trở thành permission storm.
10. Là người dùng dùng VoiceOver, tôi muốn status, lý do, kết quả request, và recovery action đều được đọc được, để consent không phụ thuộc vào màu sắc hay hover.
11. Là người dùng chỉ dùng bàn phím, tôi muốn hoàn tất explanation, confirm, và recovery action theo thứ tự focus dự đoán được, để luồng permission có thể truy cập không cần chuột.
12. Là người dùng, tôi muốn thông báo recovery không chứa transcript, clipboard, file, audio, screen content, token, hay dữ liệu nhạy cảm, để opt-in không làm lộ nội dung riêng tư.
13. Là người dùng, tôi muốn mở onboarding hoặc quay lại ứng dụng không tự tạo prompt, để các entry point thụ động vẫn yên tĩnh.
14. Là người dùng, tôi muốn một request đang chạy không tạo prompt thứ hai khi tôi bấm lại, để interaction không gây khó hiểu.
15. Là người dùng, tôi muốn trạng thái unavailable hoặc restricted giải thích được khi System Settings không thể giải quyết, để tôi không theo một recovery path vô ích.
16. Là người dùng, tôi muốn Notch surface và menu-bar recovery path vẫn hoạt động khi permission bị từ chối, để privacy choice không làm mất đường điều khiển chính.
17. Là maintainer, tôi muốn mọi kiểm tra và request đi qua PermissionCoordinator, để có một policy boundary có thể audit.
18. Là maintainer, tôi muốn raw macOS authorization status bị giữ trong adapter, để UI và audit không phụ thuộc API-specific state hoặc vô tình log dữ liệu không cần thiết.
19. Là maintainer, tôi muốn request context bắt buộc có feature ID, human-readable reason, user initiation và source, để coordinator có thể từ chối prompt không hợp lệ trước khi chạm macOS.
20. Là maintainer, tôi muốn F5 có platform-level capability requirement thay vì ModuleRuntime, để F7 vẫn sở hữu lifecycle và metadata của Module thật.
21. Là tác giả Module tương lai, tôi muốn một contract capability đã rõ ràng nhưng không bị bắt buộc start một Module để kiểm tra status, để F7 có thể nối capability vào lifecycle đúng phase.
22. Là tác giả shortcut tương lai, tôi muốn Accessibility chưa được request trong F5, để F6 có thể chọn implementation trước khi app xin một quyền mạnh.
23. Là security reviewer, tôi muốn một request không do user khởi tạo, không có lý do, hoặc không có requirement phù hợp bị reject, để module/view không thể lách consent policy.
24. Là security reviewer, tôi muốn denied và revoked là normal degraded states, để app không retry loop hoặc tiếp tục truy cập sau khi quyền thay đổi.
25. Là quality engineer, tôi muốn mô phỏng all normalized status transitions ở một seam, để test không thay đổi permission thật của máy phát triển.
26. Là quality engineer, tôi muốn kiểm tra refresh khi app active qua public coordinator behavior, để status lifecycle không bị buộc vào SwiftUI view internals.
27. Là documentation reviewer, tôi muốn docs, requirements, roadmap, Apple API record và Settings copy cùng mô tả Notifications scope, để implementation không vượt F5 do tài liệu mâu thuẫn.
28. Là release reviewer, tôi muốn manual evidence trên signed development/release-like build cho prompt, denial, System Settings recovery và revocation, để mock không bị coi là bằng chứng native macOS.
29. Là contributor, tôi muốn F5 không thêm general notification delivery policy hay setting, để quyền Notifications không trở thành một feature notification chưa có owner.
30. Là future F9 maintainer, tôi muốn F5 chỉ tạo audit metadata sanitize, không có diagnostics retention/export, để F9 vẫn sở hữu operational history.

## Implementation Decisions

- Dùng thuật ngữ glossary **Capability**, **App shell**, **Application scene**, **Module**, và không gọi capability là direct permission access. `PermissionKind` biểu diễn nhóm system access; `PermissionStatus` chuẩn hóa `notDetermined`, `authorized`, `denied`, `restricted`, và `unavailable` khi capability thực sự có owner/request path.
- `PermissionCoordinator` là public high-level boundary duy nhất. Nó nhận request context, kiểm tra user initiation, feature ID, human-readable reason, source, capability requirement và trạng thái hiện tại trước khi gọi adapter; nó cũng publish projection, mở System Settings, refresh, deduplicate request cùng capability, và phát audit metadata đã sanitize.
- Chỉ một `PermissionAdapter` của Notifications được production-enable trong F5. Adapter là nơi duy nhất import/call UserNotifications và ánh xạ raw platform status sang product-level status cộng reason hiển thị được. Raw status không đi vào UI, public projection, hoặc audit output.
- Các capability future vẫn xuất hiện như informational rows khi phù hợp, với trạng thái not used by enabled features thay vì `unavailable` hoặc missing permission. Không thêm adapter/request path giả cho chúng; không request Accessibility trong F5.
- Dùng platform-level capability requirement cho feature/context validation. Không thay đổi Module lifecycle hay khởi tạo ModuleRuntime; F7 chịu trách nhiệm map requirement này sang metadata và runtime của Module thật.
- Permission row của Settings shell trở thành interactive chỉ khi coordinator được composition root cung cấp. Row Notifications hiển thị friendly name, capability reason, status, data implication, explanation, decline effect và một action phù hợp. Route phải còn unavailable rõ ràng khi F5 owner không được composition.
- Luồng prompt gồm explicit user intent, pre-permission explanation, explicit confirm từ Settings Permissions, coordinator request, projection update và next-step presentation. Opening Settings, opening Permissions, app launch, app activation, passive refresh, hoặc onboarding display không được tự prompt; F5 không nhận request source ngoài Settings.
- Khi Notifications là denied, primary recovery là System Settings; khi restricted hoặc unavailable, UI giải thích rằng Mac hoặc policy quản lý trạng thái và không hứa một recovery action không thể thực hiện. Coordinator không tự retry khi activation. Khi authorization đổi ngoài app, activation-triggered refresh cập nhật projection và tạo degraded state an toàn.
- Permission recovery notification xác định consent scope F5 duy nhất. F5 hiện chỉ sở hữu authorization/recovery state, không delivery/content path; khi một phase sau thêm delivery, nội dung phải ngắn, không nhạy cảm, và chỉ liên quan outcome/recovery của Permission Center. F5 không tạo Action/Module event notification, background policy chung, scheduler, history, notification preference schema, hoặc generic Settings toggle.
- App shell composition có thể forward activation tới coordinator refresh thông qua một dependency hẹp. Permission service không sở hữu lifecycle của App shell, Notch surface, module, hay scene; App shell vẫn là lifecycle owner.
- Audit output chỉ chứa permission kind, normalized before/after status, request source/feature ID, outcome, timestamp, app version và việc explanation đã được hiển thị. Nó không tạo F9 Diagnostics store, retention, export, raw system values, screenshot prompt, hay user content.
- ADR-0008 giữ nguyên và không cần ADR mới: F5 áp dụng central coordinator/on-demand policy đã accepted. Mọi thay đổi sau này về privileged helper, entitlement, distribution-sensitive behavior, hoặc general notification delivery phải qua ADR review theo public-API policy.

## Testing Decisions

- Seam tự động chính và cao nhất là `PermissionCoordinator` với `PermissionAdapter`, capability-requirement provider, projection observer, System Settings opener và audit sink có thể inject. Test quan sát request/result/projection/recovery; không assert SwiftUI body, `UNUserNotificationCenter` call sequence, hay raw authorization enum.
- Prior art là `SettingsStore` với backend injectable cho success/failure, `AppCoordinator` với lifecycle adapter injectable, và `SettingsShellModel` với route state. F5 tiếp tục Swift Testing style hiện có và không cần test-only hook trong mỗi view.
- Adapter fake phải mô phỏng `notDetermined → authorized`, `notDetermined → denied`, `authorized → denied/revoked`, `restricted`, `unavailable`, mở System Settings failure, và request completion. Test không được thay đổi authorization thật của máy.
- Cover request-context rejections: user initiation false, missing/blank reason, unknown feature, capability không có requirement, unsupported future capability, recovery source cố prompt, và duplicate request. Mọi rejection phải không gọi adapter request.
- Cover Notifications success, denial, restricted, unavailable, status refresh sau app activation, return từ System Settings, request deduplication, and no retry loop. Verify UI projection exposes a textual reason and correct next action.
- Cover accessibility-visible outcomes at the Settings-facing model: permission row label/status/reason/action, pre-prompt explanation, denied recovery, status change announcement, keyboard-reachable confirm/recovery, and no color-only state. Không dùng snapshot/UI automation thay thế coordinator behavior tests.
- Cover no-side-effect boundaries: app launch, Settings open, Permissions page open, onboarding display, passive refresh, and activation may query/refresh but never request. Verify no ModuleRuntime, Action Registry, IPC, Notch panel, general notification scheduler, Settings snapshot mutation, or F9 retention is created by F5 flow.
- Cover audit sanitization: expected metadata is emitted; raw authorization status, secret, content payload, and sensitive notification body never reach audit sink. F5 has no delivery/content path, so granted/revoked delivery suppression is a future delivery-phase test rather than F5 evidence.
- Repository verification runs formatter, package tests, macOS build, Markdown-link check, and secret scan through the established composite command. F5 evidence records automated results separately from manual macOS results.
- Manual QA on a signed development/release-like build covers first launch with all permissions not determined; opening Settings/Permissions without prompt; explanation and explicit Notifications opt-in; grant/deny; Open System Settings; return/refresh; external revoke while app is active; and VoiceOver/keyboard route. Recovery-notification content verification is deferred with its future delivery path. Unrun native rows remain pending, never inferred from mocks or builds.

## Out of Scope

- Accessibility request, global shortcut implementation, shortcut recorder, Action Registry, Action execution, confirmation owned by Actions, and all F6 behavior.
- ModuleRuntime, DemoModule, live Module metadata/lifecycle integration, module UI contribution, and any permission request initiated by a Module; these are F7 work.
- Microphone, Camera, Calendar, Reminders, Screen Recording, Automation, EventKit, AVFoundation, ScreenCaptureKit, and all corresponding real adapters or prompts.
- Generic or background notification delivery, Action/Module notifications, notification scheduling/history, a notification preference schema, a general Settings toggle, badges, sound policy, and notification content from integrations.
- F9 Diagnostics retention, export, raw logs, audit-history UI, performance telemetry, or any unbounded local record.
- IPC, local/remote APIs, `notchctl`, LAN control, Keychain/credential flow, cloud sync, account flow, private APIs, privileged helpers, new distribution entitlements, or release notarization.
- Any direct `NSPanel` ownership, Notch surface interaction change, external-display behavior, or attempt to close outstanding F2/F3 native manual QA gates.

## Further Notes

- The seam was synthesized from the accepted Permission Center documentation and ADR-0008: all user intent and lifecycle refresh converge at `PermissionCoordinator`; production macOS behavior stays behind one Notifications adapter. This is the intended F5 test boundary.
- This specification is `ready-for-agent`. It is deliberately bounded: a capability authorization proof is not permission to build a general notification platform.
- F5 completion requires a new evidence record with automated and signed native/manual results. Existing F2 and F3 manual gates remain independently pending and must not be reclassified by F5 work.
