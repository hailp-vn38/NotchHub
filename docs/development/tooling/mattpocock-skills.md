# Hướng dẫn sử dụng `mattpocock/skills`

## 1. Tổng quan

[`mattpocock/skills`](https://github.com/mattpocock/skills) là một bộ **Agent Skills dành cho software engineering**.

Mục tiêu của bộ skill này là giúp coding agent làm việc theo một quy trình có cấu trúc hơn, ví dụ:

```text
Ý tưởng
   ↓
Làm rõ yêu cầu
   ↓
Viết spec
   ↓
Chia ticket
   ↓
Implement
   ↓
TDD
   ↓
Code review
   ↓
Commit
```

Thay vì chỉ yêu cầu AI:

```text
Hãy code feature này
```

bạn có thể dùng các workflow như:

```text
/grill-with-docs
/to-spec
/to-tickets
/implement
```

để yêu cầu được phân tích, thiết kế và triển khai có hệ thống.

---

# 2. Cài đặt

## 2.1. Cài bằng `skills.sh`

Trong thư mục project:

```bash
cd your-project

npx skills@latest add mattpocock/skills
```

Installer sẽ cho phép:

- Chọn các skill muốn cài.
- Chọn coding agent sẽ sử dụng skill.
- Cài skill trực tiếp vào project.

Nên cài ít nhất:

```text
setup-matt-pocock-skills
```

Nếu chỉ muốn cài một skill cụ thể:

```bash
npx skills add https://github.com/mattpocock/skills --skill tdd
```

Ví dụ:

```bash
npx skills add https://github.com/mattpocock/skills --skill diagnosing-bugs
```

Để cập nhật các skill đã cài:

```bash
npx skills update
```

---

## 2.2. Cài cho Claude Code

Nếu sử dụng Claude Code:

```bash
claude plugins install mattpocock-skills
```

Hoặc bên trong Claude Code:

```text
/plugin install mattpocock-skills
```

> Nên chọn một phương thức cài đặt: plugin hoặc `skills.sh`, tránh cài trùng cùng một bộ skill.

---

# 3. Setup project lần đầu

Sau khi cài skill, trong mỗi repository nên chạy một lần:

```text
/setup-matt-pocock-skills
```

Skill này cấu hình môi trường làm việc cho các skill còn lại.

Nó có thể hỏi những thông tin như:

```text
Issue tracker?
> GitHub

Where should domain docs live?
> docs/

Which labels should triage use?
> ...
```

Sau bước này, repository đã sẵn sàng để dùng workflow của `mattpocock/skills`.

---

# 4. Skill nên nhớ đầu tiên: `ask-matt`

Nếu không biết nên dùng skill nào:

```text
/ask-matt
```

`ask-matt` đóng vai trò như một **router**.

Nó đánh giá công việc hiện tại và hướng bạn đến workflow phù hợp.

Ví dụ:

```text
Ý tưởng
   ↓
/grill-with-docs
   ↓
/to-spec
   ↓
/to-tickets
   ↓
/implement
   ↓
/tdd
   ↓
/code-review
```

Với task nhỏ, có thể bỏ qua:

```text
/to-spec
/to-tickets
```

và đi thẳng từ:

```text
/grill-with-docs
```

sang:

```text
/implement
```

---

# 5. Các skill quan trọng

| Tình huống | Skill |
|---|---|
| Không biết nên dùng gì | `/ask-matt` |
| Yêu cầu còn mơ hồ | `/grill-with-docs` |
| Ý tưởng ngoài codebase | `/grill-me` |
| Feature nhỏ | `/tdd` |
| Debug bug khó | `/diagnosing-bugs` |
| Prototype nhanh | `/prototype` |
| Biến discussion thành spec | `/to-spec` |
| Chia spec thành ticket | `/to-tickets` |
| Implement spec/ticket | `/implement` |
| Review code | `/code-review` |
| Project rất lớn, nhiều quyết định | `/wayfinder` |
| Cải thiện kiến trúc | `/improve-codebase-architecture` |
| Chuyển việc sang session khác | `/handoff` |
| Giải quyết merge conflict | `/resolving-merge-conflicts` |

---

# 6. Workflow cho feature mới

Giả sử muốn thêm một feature:

```text
Tôi muốn thêm cơ chế reconnect BLE khi thiết bị mất kết nối.
```

## Bước 1 — Làm rõ yêu cầu

Chạy:

```text
/grill-with-docs
```

Agent sẽ hỏi về:

- Behavior.
- Constraints.
- Edge cases.
- Thuật ngữ domain.
- Quyết định kiến trúc.
- Cách feature tương tác với code hiện tại.

Mục tiêu là không code quá sớm khi yêu cầu chưa rõ.

---

## Bước 2 — Tạo spec

Sau khi yêu cầu đã rõ:

```text
/to-spec
```

Skill này chuyển discussion thành một specification có cấu trúc.

Ví dụ spec có thể bao gồm:

```text
Goal
Requirements
Non-goals
Architecture
State transitions
Error handling
Testing strategy
```

---

## Bước 3 — Chia ticket

Chạy:

```text
/to-tickets
```

Spec sẽ được chia thành những phần nhỏ có thể triển khai độc lập.

Ví dụ:

```text
Ticket 1
Add BLE connection state model

Ticket 2
Add reconnect scheduler

Ticket 3
Implement retry policy

Ticket 4
Add reconnect integration tests

Ticket 5
Update documentation
```

---

## Bước 4 — Implement

Chạy:

```text
/implement
```

Agent sẽ thực hiện từng phần.

Workflow thường có dạng:

```text
implement
   ↓
tdd
   ↓
code-review
```

---

# 7. Workflow TDD

Skill:

```text
/tdd
```

sử dụng vòng lặp:

```text
RED
↓
GREEN
↓
REFACTOR
```

## RED

Viết test thể hiện behavior cần có.

Test phải fail.

Ví dụ:

```text
BLE device disconnects
↓
reconnect should be scheduled
```

---

## GREEN

Viết lượng code nhỏ nhất để test pass.

---

## REFACTOR

Cải thiện:

- Naming.
- Structure.
- Duplication.
- Abstraction.

Nhưng vẫn giữ toàn bộ test pass.

Sau đó chuyển sang behavior tiếp theo.

---

# 8. Workflow sửa bug

Giả sử có bug:

```text
Một client đôi khi không reconnect sau khi phiên kết nối bị khởi động lại.
```

Không nên bắt đầu bằng:

```text
Fix reconnect bug
```

Thay vào đó:

```text
/diagnosing-bugs
```

Workflow thường là:

```text
Reproduce
   ↓
Minimize
   ↓
Create hypothesis
   ↓
Instrument
   ↓
Verify hypothesis
   ↓
Fix
   ↓
Regression test
```

Điểm quan trọng là agent phải **tái hiện được bug trước khi sửa**.

Điều này giúp tránh tình trạng:

```text
đọc code
↓
đoán nguyên nhân
↓
sửa thử
```

---

# 9. Feature nhỏ

Nếu feature nhỏ và yêu cầu khá rõ:

```text
Add timeout support to BLE command execution.

Default timeout: 5 seconds.
```

Có thể dùng workflow ngắn:

```text
/grill-with-docs
```

sau đó:

```text
/implement
```

Agent sẽ tự sử dụng:

```text
tdd
code-review
```

khi cần.

Workflow:

```text
grill-with-docs
       ↓
   implement
       ↓
      tdd
       ↓
 code-review
```

---

# 10. Feature lớn

Ví dụ:

```text
Refactor BLE Central để hỗ trợ:

- nhiều peripheral
- connection pool
- auto reconnect
- event-driven architecture
```

Nên sử dụng đầy đủ:

```text
/grill-with-docs
```

↓

```text
/to-spec
```

↓

```text
/to-tickets
```

Sau đó mỗi ticket có thể triển khai bằng:

```text
/implement
```

---

# 11. Project quá lớn: dùng `wayfinder`

Nếu task rất lớn và chưa rõ hướng thiết kế:

```text
Redesign architecture toàn bộ ứng dụng.
```

Không nên ngay lập tức chạy:

```text
/to-spec
```

Thay vào đó:

```text
/wayfinder
```

`wayfinder` tập trung tìm và giải quyết các quyết định lớn trước.

Ví dụ:

```text
Transport architecture?
BLE connection model?
Device registry?
Command routing?
Event system?
Persistence?
```

Sau khi các quyết định chính đã rõ:

```text
/wayfinder
      ↓
/to-spec
      ↓
/to-tickets
      ↓
/implement
```

---

# 12. User-invoked và model-invoked skills

Trong bộ `mattpocock/skills` có hai nhóm chính.

## User-invoked

Bạn chủ động gọi:

```text
/grill-with-docs
/to-spec
/to-tickets
/implement
/ask-matt
```

Những skill này thường đóng vai trò orchestration.

---

## Model-invoked

Agent có thể tự sử dụng khi cần:

```text
tdd
code-review
domain-modeling
codebase-design
diagnosing-bugs
```

Ví dụ:

```text
/implement
```

có thể tự dẫn tới:

```text
tdd
```

và cuối cùng:

```text
code-review
```

---

# 13. Bộ skill tối thiểu nên cài

Không nhất thiết phải cài toàn bộ repository.

Một bộ cơ bản tốt:

```text
setup-matt-pocock-skills
ask-matt

grill-with-docs
to-spec
to-tickets
implement

tdd
diagnosing-bugs
code-review

domain-modeling
codebase-design

handoff
```

Sau khi quen workflow có thể thêm:

```text
prototype
wayfinder
triage
improve-codebase-architecture
research
wizard
```

---

# 14. Workflow đề xuất cho project

Với một project bất kỳ, có thể bắt đầu bằng việc cài bộ skill và chọn workflow phù hợp:

Ví dụ:

```text
Add automatic BLE reconnect with exponential backoff.
```

Bắt đầu:

```text
/grill-with-docs
```

Nếu feature lớn:

```text
/to-spec
```

```text
/to-tickets
```

Sau đó:

```text
/implement
```

---

## Khi sửa bug

Ví dụ:

```text
BLE device fails to reconnect after peripheral reboot.
```

Chạy:

```text
/diagnosing-bugs
```

---

## Khi refactor architecture

Ví dụ:

```text
Refactor components/ble_central.
```

Có thể dùng:

```text
/improve-codebase-architecture
```

hoặc nếu phạm vi lớn:

```text
/wayfinder
```

---

# 15. Workflow khuyến nghị

## Task nhỏ

```text
/grill-with-docs
       ↓
/implement
       ↓
/code-review
```

---

## Task trung bình

```text
/grill-with-docs
       ↓
/to-spec
       ↓
/implement
       ↓
/code-review
```

---

## Task lớn

```text
/grill-with-docs
       ↓
/to-spec
       ↓
/to-tickets
       ↓
/implement
       ↓
/code-review
```

---

## Task cực lớn / kiến trúc

```text
/wayfinder
       ↓
/grill-with-docs
       ↓
/to-spec
       ↓
/to-tickets
       ↓
/implement
```

---

# 16. Nguyên tắc sử dụng

## Không code quá sớm

Nếu requirement chưa rõ:

```text
/grill-with-docs
```

trước khi:

```text
/implement
```

---

## Bug phải reproduce trước

Dùng:

```text
/diagnosing-bugs
```

thay vì chỉ yêu cầu:

```text
Fix this bug
```

---

## Feature lớn nên có spec

Nếu task có:

- nhiều component
- nhiều state
- nhiều edge case
- thay đổi architecture

thì nên:

```text
/to-spec
```

---

## Dùng ticket để giảm context

Thay vì implement một feature khổng lồ trong một session:

```text
spec
↓
tickets
↓
implement từng ticket
```

Điều này giúp agent:

- Ít mất context.
- Giảm hallucination.
- Review dễ hơn.
- Commit nhỏ hơn.
- Rollback dễ hơn.

---

# 17. Cheat Sheet

```text
Không biết dùng gì
    ↓
/ask-matt
```

```text
Requirement chưa rõ
    ↓
/grill-with-docs
```

```text
Cần specification
    ↓
/to-spec
```

```text
Feature lớn
    ↓
/to-tickets
```

```text
Code feature
    ↓
/implement
```

```text
Viết theo TDD
    ↓
/tdd
```

```text
Bug khó
    ↓
/diagnosing-bugs
```

```text
Review code
    ↓
/code-review
```

```text
Architecture lớn
    ↓
/wayfinder
```

```text
Không biết bước tiếp theo
    ↓
/ask-matt
```

---

# 18. Workflow mặc định nên dùng

Nếu chưa quen bộ skill này, có thể dùng quy tắc đơn giản:

```text
Feature nhỏ
→ /grill-with-docs
→ /implement
```

```text
Feature lớn
→ /grill-with-docs
→ /to-spec
→ /to-tickets
→ /implement
```

```text
Bug
→ /diagnosing-bugs
```

```text
Không biết làm gì tiếp
→ /ask-matt
```

Đây là đủ để sử dụng phần lớn giá trị của `mattpocock/skills`.

---

# Tham khảo

- Repository: https://github.com/mattpocock/skills
- Skills directory: https://skills.sh/mattpocock/skills
