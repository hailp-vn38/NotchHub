# F5 Permission Center Evidence

**Status:** Automated gates passed; native manual gate pending
**Phase:** F5 — Permission Center
**Owner:** Platform / Security / UX
**Recorded:** 2026-09-15

## Evidence boundary

F5 introduces a central, testable Permission Coordinator and a single real Notifications adapter.
Automated tests prove the public coordinator and Settings seams with fakes; they do not grant,
deny, revoke, or inspect a real macOS authorization state. A build, mock, or rendered Settings
scene is not evidence that the system prompt, System Settings recovery, VoiceOver, or external
revocation works on a physical macOS desktop.

## Automated verification

| Gate | Evidence | Result |
|---|---|---|
| Permission Coordinator policy | Passive/malformed/non-Settings request rejection before adapter; `notDetermined` confirmation; denied, restricted, and unavailable no-retry states; external-revoke refresh; concurrent-request deduplication | **PASS** — focused Swift Testing tests |
| Sanitized audit boundary | Audit includes only normalized before/after status and consent context | **PASS** — focused Swift Testing test |
| Settings behavior | Permissions route stays passive until explanation confirmation; future capability rows remain informational | **PASS** — focused Swift Testing test |
| App shell lifecycle | Only app activation forwards a permission-status refresh through the injected seam | **PASS** — focused Swift Testing test |
| Full package suite | `swift test` | **PASS** — 71 tests |
| Repository Debug app | `xcodebuild -project NotchHub.xcodeproj -scheme NotchHub -configuration Debug -destination 'platform=macOS' build` | **PASS** |
| Static/documentation checks | formatter, `git diff --check`, Markdown links | **PASS** |

## Native manual QA still required

Run on a signed development/release-like build and record the Mac model, macOS version, build,
date, and tester:

1. Launch the app and open Settings → Permissions; verify there is no prompt.
2. Read the Notifications recovery explanation with keyboard and VoiceOver; cancel it and verify no
   request occurs.
3. Confirm the opt-in; exercise both grant and deny in the real macOS prompt.
4. From denied state, use Open System Settings, change the setting, return to NotchHub, and verify
   status refreshes on activation without a retry prompt.
5. Revoke an authorized Notifications permission outside the app while it is running; verify the
   visible status changes. F5 currently owns consent/recovery state only; notification delivery
   content and scheduling are deliberately deferred, so there is no F5 delivery to inspect.
6. Verify future capability rows remain “Not used” and do not request Accessibility, Microphone,
   Camera, Calendar, Reminders, Screen Recording, or Automation.

## Gate decision

The F5 automated implementation gate is **passed**. The F5 native manual permission gate remains
**pending human QA**. This record does not close F2 or F3 native manual gates, and it does not
authorize notification delivery/content, Actions, shortcuts, Module runtime, or F9 diagnostics
retention.
