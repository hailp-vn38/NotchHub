# 01: Coordinator admission contract

**What to build:** Người dùng có một quyết định expansion đáng tin cậy: topology đủ chỗ cho fixed host thì Surface được phép mở; topology hợp lệ nhưng thiếu chỗ giữ Surface an toàn và phản hồi đúng; topology invalid hoặc native panel failure đi recovery. Diagnostics phân biệt rõ hai nhóm này.

**Blocked by:** None (can start immediately).

**Status:** resolved

- [x] Coordinator phân biệt request click/keyboard/hover giữa admitted, unsupported capacity, invalid topology và native failure mà không scale/crop expanded Surface.
- [x] Surface snapshot expose expanded availability theo topology revision; rejection feedback có vòng đời bounded và historical event chỉ nằm trong Diagnostics.
- [x] Coordinator-level tests chứng minh unsupported capacity không vào recovery, còn invalid topology/native failure vẫn recovery theo F2 contract.

## Implementation notes

- `SurfaceExpansionAdmitting` trả về `SurfaceExpandedAvailability` gồm `unknown`, `available`, `unsupportedCapacity` và `invalidTopology`, luôn gắn `topologyRevision`.
- `SurfaceCoordinator` kiểm tra admission trước transition `.expanded`. Capacity thiếu giữ nguyên `.collapsed`/`.compact`, hover bị silent; request tường minh nhận `SurfaceAdmissionFeedback` có thời hạn 3 giây.
- Invalidation xóa feedback cũ, re-read availability của topology hiện hành rồi mới chạy F2 recovery. Native expanded-panel apply failure và topology invalid vẫn đi recovery; rejection capacity không đi recovery.
- `SurfaceDiagnostics` giữ bounded history tối đa 20 event, tách khỏi snapshot presentation.
- `NotchPanelController` là production adapter duy nhất tính admission cho host cố định `640 × 210 pt`; geometry đủ/thiếu/invalid được phân loại trước khi mở.

## Verification boundary

- `swift test`: 36 tests passed; `git diff --check`: passed.
- Native window-server, accessibility announcement và keyboard event wiring thực tế vẫn cần manual QA / các ticket Surface kế tiếp; không coi build/unit test là bằng chứng runtime macOS.

## Comments

2026-09-14 — Implemented and committed as `2d1a006` (`feat(surface): add expansion admission contract`). Automated coordinator contract is complete; human/native verification remains intentionally pending.

2026-09-15 — Đóng ticket theo yêu cầu người dùng; giới hạn human/native verification được giữ nguyên.
