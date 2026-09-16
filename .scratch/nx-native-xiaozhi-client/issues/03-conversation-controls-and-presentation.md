# 03: NX conversation controls and presentation

**What to build:** Người dùng điều khiển cuộc hội thoại đang chạy từ Notch surface và nhận trạng thái/transcript ngắn gọn, camera-safe, mà không biến Notch surface thành nơi chứa protocol hoặc lịch sử dài.

**Blocked by:** 02: NX authenticated voice session and audio.

**Status:** ready-for-agent

- [ ] Expanded Notch surface cung cấp Start, Push-to-Talk, Abort và Retry; Settings/Diagnostics bền vững ở application scene.
- [ ] Listening, thinking, speaking, error, STT và TTS sentence state được project thành bounded normalized Module state.
- [ ] Transcript chỉ sống trong session memory; muted TTS có assistant ticker một dòng camera-safe và không có persistent history.
- [ ] Module disable hoặc failure gỡ Action, Surface contribution và resource mà không để raw text, token hoặc audio vào shared EventBus/diagnostics.
