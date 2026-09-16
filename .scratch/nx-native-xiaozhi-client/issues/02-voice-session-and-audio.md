# 02: NX authenticated voice session and audio

**What to build:** Người dùng có thể chủ động bắt đầu một session Xiaozhi đã xác thực, nói qua Microphone và nghe TTS, với Auto hoặc Push-to-Talk, trong khi mọi audio/network buffer được bounded.

**Blocked by:** 01: NX readiness, identity and activation.

**Status:** ready-for-agent

- [ ] User Start tạo WebSocket session, hoàn tất hello/session-ID và project state kết nối đã chuẩn hóa thay vì raw protocol.
- [ ] Auto và Push-to-Talk capture audio chỉ sau Action của người dùng, gửi uplink Opus 16 kHz mono/60 ms có giới hạn latency.
- [ ] Official libopus 1.6.1 được đóng gói từ source/checksum pin thành reproducible XCFramework và chỉ được gọi qua thin Swift wrapper; không thêm AudioKit, FFmpeg, libopusenc hoặc third-party Swift wrapper.
- [ ] TTS binary được decode, phát qua AVAudioEngine/AVAudioPlayerNode theo negotiated parameters và không phát stale audio khi queue chịu áp lực.
- [ ] Fake-server tests xác minh headers, hello, session, listen start/stop, malformed input, audio bounds và secret redaction.
