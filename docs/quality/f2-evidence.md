# F2 Evidence

**Status:** Automated gates passed; native manual gate pending
**Phase:** F2 follow-up — Boring-inspired hover Surface
**Owner:** Platform / Quality
**Recorded:** 2026-09-14

## Evidence boundary

This record separates deterministic contract evidence from proof that requires the macOS window
server, accessibility system, pointer routing, display lifecycle, or a human observing the real
surface. A passing build, package test, adapter test, or source inspection is not native runtime
proof. F2 remains open until every applicable native row has a real result or an explicitly
accepted limitation.

## Build and hardware context

| Field | Value |
|---|---|
| Checkout | `b1998374910afaf87694a514040b2ac0d6bb30c4` (`docs(surface): update accessibility lifecycle evidence`) |
| Mac | MacBook Pro `MacBookPro18,3`, Apple M1 Pro |
| macOS | 26.5.1 (25F80) |
| Xcode | 26.0.1 (17A400) |
| Display | Built-in Liquid Retina XDR, 3024 × 1964 Retina; physical-notch host |
| External display | Not connected during this run |
| Build | Debug `NotchHub.app`; unsigned/local development build |
| Tester | Codex interactive session |

## Automated verification

| Gate | Command / coverage | Result |
|---|---|---|
| Full package suite | `swift test` | **Passed** — 41 tests, 0 failures |
| Coordinator admission/capability | admitted, undersized valid, invalid topology, native apply failure, topology revision | **Passed** |
| Shape and geometry | physical-notch, no-notch fallback, fixed `640 × 190 pt` Surface / `640 × 210 pt` host, scale/resolution reframe | **Passed** |
| Pointer contract | visible-shape hit testing, transparent corner/shadow envelope, hidden/suppressed safety, capture/input seam | **Passed** |
| Hover/session | 300 ms dwell, 100 ms grace, re-entry cancellation, click/keyboard inactivity, typed hold leases, stale releases | **Passed** |
| Lifecycle/accessibility | focus restoration, accessibility hold lifecycle, full-screen/Space, sleep/wake, lock/unlock, recovery | **Passed** |
| Repository build | `xcodebuild -project NotchHub.xcodeproj -scheme NotchHub -configuration Debug -destination 'platform=macOS' build` | **Passed** |

The automated undersized-topology test proves the required policy: a valid topology that cannot
admit the fixed host stays out of recovery; hover remains silent while explicit click/keyboard
requests produce bounded admission feedback and a Diagnostics event. Invalid topology and native
panel failure are separately covered as recovery paths. The no-notch case is synthetic geometry
evidence only, not proof on a no-notch Mac.

## Native manual QA matrix

No native row is inferred from the results above. The current session could build and launch the
Debug app, but did not obtain an observable panel accessibility tree or screenshot, so these rows
remain pending a human-operated physical-notch QA run.

| Scenario | Result | Required evidence |
|---|---|---|
| Launch, collapsed physical-notch shape, fixed size | **Unrun** | Observe attached placement, no persistent product text, and measured stable host/surface size. |
| Morph open/close, shoulder shape, no frame jump | **Unrun** | Observe continuous `6/14` → `19/24` morph, top seam/shadow, no host swap or stale settle resize. |
| Hover dwell and 100 ms grace/re-entry | **Unrun** | Time incidental pass, exit, re-entry, and repeated open/close on the real pointer. |
| Click-through and pointer re-entry | **Unrun** | Click transparent corners/shadow and an unrelated app; re-enter visible shape and interact again. |
| Click/keyboard access, Escape, click-outside, focus restoration | **Unrun** | Verify deliberate feedback, safe exits, no focus steal/trap, and prior-key-window restoration. |
| VoiceOver and accessibility hold | **Unrun** | Navigate expanded controls with VoiceOver; verify collapse never strands focus or closes during active assistive interaction. |
| Reduce Motion | **Unrun** | Enable the system setting and verify short understandable non-spring feedback without overshoot. |
| Spaces and another app full-screen | **Unrun** | Verify join-Space behavior, suppression during full-screen, and collapsed return after clearing policy. |
| Sleep/wake, lock/unlock, display invalidation | **Unrun** | Exercise each transition while collapsed and expanded; verify bounded recovery and no stale capture/hold. |
| Rapid reopen during host settle | **Unrun** | Collapse and reopen before settling completes; verify host remains fixed and visible. |
| Undersized valid topology | **Unrun on native topology** | Use a valid but too-small geometry; hover must be silent, explicit input accessible/bounded, Diagnostics records rejection, no recovery. |
| No-notch behavior | **Limited** | Synthetic fallback passes. No no-notch hardware was available; native fallback behavior is not claimed. |

## Gate decision

The automated F2 contract gate is **passed**. The native macOS evidence gate is **pending human
QA**, so this artifact does not close F2 and does not claim physical visual, input, accessibility,
or lifecycle behavior as verified.
