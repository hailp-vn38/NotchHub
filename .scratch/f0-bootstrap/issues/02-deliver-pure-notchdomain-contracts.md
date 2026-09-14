# 02: Deliver pure NotchDomain contracts

**What to build:** NotchDomain cung cấp các typed contract tối thiểu cho identity, state, error, Event envelope, Action và Module, để các phase sau có thể dùng cùng vocabulary mà không kéo SwiftUI, AppKit hoặc I/O vào domain.

**Blocked by:** 01 — Bootstrap project spine.

**Status:** resolved

- [x] Các pure-domain contract dùng canonical glossary vocabulary và build trong NotchDomain.
- [x] Có ít nhất một pure-domain test kiểm chứng contract có thể dùng được.
- [x] Kiểm tra boundary chứng minh NotchDomain không import SwiftUI hoặc AppKit.

## Answer

Đã thêm pure Swift contracts cho identity, state, error, Event envelope, Action và Module trong `NotchDomain`; test encode/decode và rejection chạy qua `swift test`. `Scripts/check-domain-boundary.sh` được gọi từ `./Scripts/verify.sh` để chặn import SwiftUI/AppKit. Gate đầy đủ `./Scripts/verify.sh` đã pass.
