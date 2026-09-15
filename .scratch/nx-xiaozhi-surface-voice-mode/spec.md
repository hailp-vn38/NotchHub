# NX — Xiaozhi Surface Voice Mode

Status: ready-for-agent

## Problem Statement

Người dùng có thể khởi động Xiaozhi từ action ở Surface home, nhưng Surface hiện chỉ trình bày text và action generic. Nó chưa có UI hội thoại dành riêng cho Xiaozhi, chưa thể hiện trạng thái voice hai bên physical notch, chưa có TTS-muted ticker lấy text assistant từ WebSocket, và chưa có vòng đời tự đóng an toàn khi câu trả lời kết thúc. Người dùng không muốn các điều khiển gửi/dừng thủ công trong Surface voice mode.

## Solution

Dùng đúng một Notch surface/panel hiện có. Khi action home bắt đầu một Auto Xiaozhi voice session, Xiaozhi xuất bản một Surface contribution descriptor typed chọn Surface content mode `voice`; platform thay home composition bằng renderer voice mode nhưng vẫn giữ mọi authority về geometry, hit testing, suppression, recovery và transition tại Surface. Khi TTS-muted, không phát audio mà trình bày assistant transcript ticker một dòng, camera-safe và transient. Khi session hoàn tất hoặc lỗi, module dọn tài nguyên và Surface quay về home theo thời hạn đã thống nhất.

## User Stories

1. As a người dùng macOS, I want khởi động Xiaozhi từ action ở Surface home, so that tôi bắt đầu hội thoại mà không cần mở một cửa sổ hoặc panel khác.
2. As a người dùng macOS, I want một Auto Xiaozhi session bắt đầu sau action home, so that tôi có thể nói tự nhiên mà không cần thao tác Push-to-Talk trên Surface.
3. As a người dùng macOS, I want cùng một Notch surface chuyển từ home composition sang Xiaozhi voice mode, so that trải nghiệm liên tục quanh physical notch.
4. As a người dùng macOS, I want voice mode không có nút gửi, abort, stop, hay reconnect, so that giao diện chỉ phục vụ hội thoại tự nhiên và không tạo control thủ công ngoài ý định.
5. As a người dùng macOS, I want trạng thái listening và speaking hiển thị visualizer đối xứng hai bên physical notch, so that biết Xiaozhi đang dùng voice mà không che camera cluster.
6. As a người dùng macOS, I want connecting và thinking hiển thị trạng thái tối giản, so that tôi phân biệt được các bước chờ mà không thấy raw protocol.
7. As a người dùng macOS, I want visualizer nhận activity đã chuẩn hoá thay vì raw microphone/PCM, so that Surface không nhận audio nhạy cảm hoặc cập nhật high-rate.
8. As a người dùng bật Reduce Motion, I want visualizer trở thành chỉ báo tĩnh, so that voice mode không gây chuyển động không cần thiết.
9. As a người dùng, I want TTS-muted mặc định tắt, so that Xiaozhi phát câu trả lời bình thường nếu tôi chưa chủ động đổi lựa chọn module.
10. As a người dùng bật TTS-muted, I want TTS không được phát nhưng assistant text vẫn hiển thị, so that tôi đọc được câu trả lời trong môi trường cần yên lặng.
11. As a người dùng TTS-muted, I want assistant transcript ticker chạy liên tục một dòng theo chiều trái sang phải, so that tôi đọc được câu trả lời dài trong không gian hẹp.
12. As a người dùng TTS-muted, I want ticker không xuống dòng, không đi qua vùng camera, và chỉ thể hiện assistant text hiện hành, so that giao diện vẫn camera-safe và dễ quét.
13. As a người dùng, I want ticker không lưu history và bị xoá khi session kết thúc, abort, disable, fail, reconnect hoặc Mac sleep, so that nội dung hội thoại không trở thành dữ liệu bền.
14. As a người dùng, I want `tts.stop` từ WebSocket biểu thị upstream đã kết thúc TTS, so that module có một trạng thái completion rõ ràng.
15. As a người dùng nghe TTS, I want countdown về home chỉ bắt đầu khi `tts.stop` và local playback đã drained, so that audio không bị cắt giữa câu.
16. As a người dùng TTS-muted, I want `tts.stop` trực tiếp bắt đầu khoảng giữ 3 giây, so that Surface không chờ một audio queue vốn không tồn tại.
17. As a người dùng, I want voice mode giữ completion trong 3 giây rồi tự đóng WebSocket, dừng audio, xoá ticker và về home, so that session không giữ microphone hay network vô hạn.
18. As a người dùng không cấp microphone, I want Surface giữ home composition và xem hướng dẫn ở thông tin module, so that permission không tạo một voice mode lỗi hoặc prompt lặp lại.
19. As a người dùng gặp lỗi activation hoặc kết nối sau khi voice mode bắt đầu, I want một thông báo an toàn tối đa 3 giây rồi về home, so that tôi nhận được feedback mà không lộ endpoint, token hay raw transport error.
20. As a người dùng, I want lỗi không tự reconnect hoặc tự mở lại Surface, so that một action home mới là ý định rõ ràng cho session kế tiếp.
21. As a người dùng, I want đổi TTS-muted chỉ có hiệu lực ở session kế tiếp, so that câu đang phát không bị cắt hoặc đổi layout bất ngờ.
22. As a người dùng, I want full-screen suppression, sleep/wake, lock/unlock, topology invalidation và expanded-admission policy tiếp tục áp dụng cho voice mode, so that UI module không phá lifecycle Surface.
23. As a người dùng dùng VoiceOver, I want trạng thái voice và ticker có nhãn accessibility ngắn, không announce từng animation hoặc từng text update, so that assistive interaction vẫn hữu ích và không quá tải.
24. As a maintainer, I want module-specific composition đi qua typed Surface contribution descriptor, so that Xiaozhi không sở hữu SwiftUI view, `NSPanel`, geometry hay Surface transition.
25. As a maintainer, I want mọi raw WebSocket message, audio packet, session ID, credential và unbounded transcript bị loại khỏi Surface contract, so that UI boundary vẫn protocol-agnostic và riêng tư.

## Implementation Decisions

- ADR-0018 vẫn áp dụng: Xiaozhi là Native Xiaozhi Client duy nhất, expanded content chỉ có trạng thái hội thoại tức thời; cấu hình bền, permission guidance và diagnostics thuộc application scene. ADR-0020 xác lập module-specific composition qua platform-owned Surface content mode.
- Seam feature cấp cao duy nhất là Surface contribution descriptor: `XiaozhiModule` phát một projection typed, `ModuleRuntime` quản lý lifetime/update, và `SurfaceCoordinator` chuyển projection cho platform renderer. Không có callback view hoặc AppKit dependency đi ngược về module.
- Descriptor được mở rộng để mang content mode `voice` và một Xiaozhi presentation snapshot bounded. Nó biểu diễn tối thiểu voice state, TTS-muted, assistant ticker text đã giới hạn, và activity level đã coalesce; không mang raw WS/audio/session/secret.
- Notch surface có renderer cho home mode và voice mode trong cùng root composition, không tạo NSPanel/window thứ hai, không sửa SurfaceState hay tự thay đổi geometry contract. Voice mode chỉ thay content của Surface hiện hữu.
- Action home dùng registered conversation action hiện có để tạo Auto session. Flow này không cung cấp Push-to-Talk, send, abort, stop hay reconnect interaction ở voice renderer. Các action thủ công cũ không được trình bày trong voice mode.
- `XiaozhiSettings` bổ sung non-secret `ttsMuted`, default `false`. Thay đổi setting được snapshot tại lúc tạo session và không thay đổi playback/rendering của session đang chạy.
- Voice session parse strict bounded `tts` text events. Assistant ticker chỉ nhận assistant text từ upstream TTS; text được giới hạn trước projection, thay nội dung theo câu assistant mới, không wrap, không persist và không log.
- TTS-muted ngăn enqueue/playback TTS nhưng không ngăn parse assistant text hoặc completion. Ticker chạy trái sang phải, camera-safe; Reduce Motion làm ticker đứng yên hoặc dùng presentation tĩnh thay vì animation liên tục.
- Visualizer hai bên notch chỉ hoạt động khi listening hoặc speaking và nhận activity level normalized/coalesced. Connecting/thinking dùng indicator tĩnh. Raw PCM, audio frame cadence và microphone levels không đi qua Surface descriptor.
- Voice session completion là `tts.stop` cộng `playback.drained`; ở TTS-muted, `tts.stop` là completion. Playback seam phải công bố drained một lần, sau audio buffer cuối, để coordinator session không dừng playback sớm.
- Completion tạo generation-scoped timer 3 giây. Khi timer thắng, module stop/disconnect, xoá Conversation transcript/ticker và cập nhật contribution để Surface về home. Session disable, abort, failure, reconnect, sleep hoặc một lifecycle departure phải huỷ timer và dọn tất cả resources idempotently.
- Thiếu microphone không khởi tạo voice mode hoặc session connection; thông tin module sở hữu status/guidance qua Permission Coordinator. Lỗi activation/kết nối sau entry voice mode chỉ project message an toàn, bounded 3 giây, rồi dọn và về home; không auto reconnect.
- Surface admission, hover hold, accessibility hold, full-screen suppression, display recovery và physical-notch geometry giữ nguyên hợp đồng F2. Voice mode là content, không phải một `SurfaceState` hoặc một bypass lifecycle.

## Testing Decisions

- Kiểm thử observable behavior ở seam `SurfaceContributionDescriptor → ModuleRuntime → SurfaceCoordinator/renderer`; không assert implementation details như private Task, `NSPanel`, queue array hoặc animation internals.
- Mở rộng test Xiaozhi module hiện có cho Auto home action, snapshot typed, TTS-muted setting snapshot, strict `tts.start` text parse, `tts.stop`, ticker clearing, error projection, no-autoreconnect và lifetime revocation.
- Dùng fake voice transport, audio capture/playback và deterministic scheduler để kiểm chứng completion truth table: audio session cần cả `tts.stop` và `drained`; muted cần `tts.stop`; stale callback/timer không thể đóng một session mới.
- Test playback seam báo `drained` sau buffer cuối và TTS-muted không enqueue playback. Không dùng thiết bị/voice cloud thật để kết luận unit behavior.
- Mở rộng NotchSurface presentation tests từ descriptor typed: home/voice selection, state-to-visual classification, camera-safe ticker single line, bounded/truncated Unicode Vietnamese text, Reduce Motion static fallback và accessibility labels không spam transcript delta.
- Hồi quy SurfaceCoordinator với contribution voice qua suppression, sleep/wake, lock/unlock, invalid topology, unavailable expanded capacity và stale completion timer; F2 state/geometry behavior không được thay đổi.
- Chạy full `swift test` và `Scripts/verify.sh` theo exit status/named checks. Bổ sung native macOS QA riêng: physical-notch layout, pointer/hit testing, VoiceOver, microphone permission route trong module information, TTS route, muted ticker, lifecycle interruption và real Xiaozhi backend `tts.stop`.

## Out of Scope

- Push-to-Talk UI, send/stop/abort/reconnect controls, wake word, full duplex, persistent transcript/history, transcript detail screen, MCP, raw protocol visibility, custom audio volume slider, auto reconnect sau lỗi, một panel/window Xiaozhi thứ hai, và module-provided SwiftUI/AppKit views.
- Full transcript, user transcript đồng thời với assistant ticker, multiline/scrolling transcript reader, logs/diagnostics trong Notch surface, raw audio visualizer, raw microphone level forwarding, hoặc thay đổi F2 geometry/interaction/recovery policy.

## Further Notes

- Tài liệu protocol hiện đã mô tả `tts.stop` và one-line camera-safe muted ticker; implementation hiện tại mới có state projection text chung và cần mở rộng contract một cách typed, bounded.
- Tất cả native visual/input/accessibility/audio proof là gate riêng với build/test; fixture phải dùng text tổng hợp, không dùng transcript cá nhân, token, audio thật hoặc endpoint secret.
