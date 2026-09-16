# 04: NX lifecycle hardening and qualification

**What to build:** Native Xiaozhi Client phục hồi an toàn sau reconnect, abort, sleep/wake, lỗi audio hoặc module shutdown, và được chứng minh bằng fake-server, Xiaozhi Cloud và native macOS evidence.

**Blocked by:** 03: NX conversation controls and presentation.

**Status:** ready-for-agent

- [ ] Reconnect, abort, sleep/wake, permission revoke, route change, disable và failure đều dừng audio/network, xóa session/transcript và không phát/gửi stale audio sau khi phục hồi.
- [ ] Queue pressure, malformed protocol, long-session, redaction và owned-resource cleanup có deterministic automated evidence.
- [ ] Real Xiaozhi Cloud acceptance bao gồm bootstrap, activation, authenticated session, Auto/PTT, STT, TTS, abort và reconnect.
- [ ] Native macOS QA ghi nhận microphone prompt/recovery, input/output audio, muted presentation, VoiceOver, Notch controls và lifecycle teardown.
