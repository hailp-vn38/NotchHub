# 05: Accessible Surface lifecycle integration

**What to build:** Người dùng keyboard và VoiceOver có thể dùng animated Notch surface mà không bị focus trap; Escape/click-outside/focus restoration, suppression/recovery và lifecycle macOS giữ hành vi an toàn sau khi native shape interaction được đưa vào.

**Blocked by:** 02 — Persistent animated Boring-style Notch shape; 03 — Native shape-aware click-through; 04 — Hover interaction session and holds.

**Status:** ready-for-agent

- [ ] Deliberate expansion có focus và label có nghĩa; collapsed, hidden, suppressed hoặc recovered view không giữ VoiceOver/keyboard focus stale.
- [ ] Escape, click-outside và collapse khôi phục focus an toàn; active accessibility interaction có hold đúng lifecycle.
- [ ] Full-screen, Space, sleep/wake, lock/unlock, display invalidation và panel recovery invalidate input/capture/hold stale mà không tự mở Detail.
- [ ] Accessibility/lifecycle tests và manual checks xác nhận Surface không steal focus hoặc chặn input khi không interactive.
