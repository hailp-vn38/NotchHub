# 01: NX readiness, identity and activation

**What to build:** Người dùng có thể bật Native Xiaozhi Client, xem nó đạt trạng thái `ready` mà không tự mở microphone hay WebSocket, cấu hình non-secret của module được lưu bền vững, và hoàn tất bootstrap/activation với Xiaozhi Cloud.

**Blocked by:** None (can start immediately).

**Status:** resolved

- [x] Module enablement tạo `ready` state và không tạo voice connection hoặc microphone capture khi chưa có Action do người dùng khởi tạo.
- [x] Settings application scene lưu và validate prepared-on-launch, auto reconnect, Auto/Push-to-Talk. Device-ID locally-administered và Client-ID UUID được giữ cố định trong Keychain; cloud thực tế từ chối `test-client`.
- [x] Microphone consent đi qua Permission Coordinator, có giải thích/recovery rõ ràng và không prompt lúc launch.
- [x] Bootstrap, activation, Keychain credential boundary và diagnostics redaction có automated fake-service tests cùng real Xiaozhi Cloud acceptance.

## Comments

- 2026-09-15: Cloud acceptance thành công với Device-ID `02:48:dd:77:12:f8`: bootstrap sau khi người dùng liên kết không còn trả `activation`, trả WebSocket configuration, và credential chỉ được lưu trong Keychain. Không log hoặc lưu token vào Settings/diagnostics. `swift test`, Xcode Debug build và `git diff --check` đã pass cho code liên quan.
