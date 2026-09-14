# F2 Evidence

**Status:** Automated gates passed; native manual gate pending
**Phase:** F2 — Notch surface shell
**Owner:** Platform / Quality
**Recorded:** 2026-09-14

## Scope boundary

This record proves the F2 repository slice through its public coordinator and geometry seams. It
does not represent automated adapters, a successful build, or an accessibility tree as proof that
the native `NSPanel` behaved correctly on macOS. The manual matrix below remains the required
physical-notch gate.

## Build context

| Field | Value |
|---|---|
| F2 implementation range | `69d58a5^...ef6873c` |
| Recorded checkout commit | `ef6873c` — `feat(surface): recover from context suppression` |
| Mac model | MacBook Pro (14-inch, 2021), `MacBookPro18,3`, Apple M1 Pro |
| macOS | 26.5.1 (25F80) |
| Xcode | 26.0.1 (17A400) |
| Display context | Built-in physical-notch display; no external display configuration was exercised |

## Automated verification

| Gate | Command/test target | Result | Evidence |
|---|---|---|---|
| F2 coordinator and geometry tests | `swift test` | Passed | 32 Swift Testing tests. Covers state transitions, bounded 150 ms hover and 3 s collapse, click/Escape/click-outside, Detail view reuse, full-screen suppression, Space policy, sleep/wake and lock/unlock recovery, two-attempt recovery, built-in selection, attach/detach handling, scale change and invalid topology. |
| No-notch fallback | `fallsBackSafelyWhenPhysicalNotchIsMissingOrInvalid` | Passed | Synthetic built-in display with invalid physical-notch data yields a contained top-center fallback. This is automated geometry proof only. |
| Composite F2 verification | `VERIFY_BASE_REF=69d58a5^ ./Scripts/verify.sh` | Passed | Toolchain, strict format lint, domain boundary, verification self-checks, SwiftPM resolve/build/test, Debug macOS app build, Markdown links and changed-file secret scan all exited 0. |

`verification-checks.sh` deliberately prints rejected bad-anchor, secret-like, and forbidden-domain-import fixtures. Those messages are successful negative tests, not failures of the composite gate.

## Boring-style shape slice

Ticket 02 adds the presentation primitive without claiming completion of the later native
shape-aware click-through or hover-session tickets.

| Contract | Automated evidence | Result |
|---|---|---|
| Collapsed geometry | `derivesCollapsedSizeAndExposesFixedExpandedSurfaceSizes` verifies physical-notch width plus tolerance and the safe `185 × 32 pt` fallback. | Passed |
| Fixed expanded geometry | The same test asserts the public `640 × 190 pt` visible Surface and `640 × 210 pt` host contracts. | Passed |
| Persistent presentation | `NotchPanelController` creates one `NSHostingView<NotchSurfaceRootView>` and updates an observation-backed geometry projection instead of replacing collapsed, compact, and expanded roots. | Build-verified |
| Animation and settling | `NotchSurfaceShape` animates the closed `6/14` and expanded `19/24` radii; opening prepares the fixed host before a next-run-loop projection, and closing cancels/versions its delayed host shrink. | Build-verified |
| Accessibility and motion | The root labels collapsed, compact, and expanded surfaces; Reduce Motion uses a short non-spring transition. | Build-verified |

The controller owns and cancels both the deferred open projection and close-host-settle tasks.
This prevents a stale close task from shrinking a host after it has reopened. The deterministic
automated seam remains geometry and `SurfaceCoordinator`; real `NSPanel` hierarchy identity and
window-server animation behavior require the manual cases below.

## Manual macOS verification

The host is a supported physical-notch MacBook, but this session was not granted macOS Computer
Use/accessibility permission. The Debug app was built but could not be operated or observed through
the native UI. No manual row below is inferred from source, tests, build output, or hardware model.

| Scenario | Result | Limitation / required follow-up |
|---|---|---|
| Launch/relaunch; collapsed surface | Unrun | Launch the Debug app, use the menu-bar Toggle NotchHub control, and confirm the panel appears around the built-in notch without stealing unrelated menu-bar input. |
| Hover, click, Escape, click-outside, timeout, repeated open/close | Unrun | Verify 150 ms hover, bounded hit target, 3 s inactivity collapse, focus behavior, and repeated lifecycle without stuck panels. |
| Detail view and close/reuse | Unrun | Open `View detail`, repeat the request to confirm focus/reuse, then close it and confirm the Notch surface has no detail state. |
| Spaces and other-app full-screen | Unrun | Confirm collection behavior reaches Spaces; confirm F2 suppresses during other-app full-screen and returns collapsed after exit. |
| Sleep/wake and lock/unlock | Unrun | Perform real system transitions with collapsed and expanded surface; confirm revalidation/recovery does not crash or leave a stuck panel. |
| Attach/detach external display, lid, resolution/scale | Unrun | Change topology while visible; confirm only built-in display is targeted and clamshell/external-only context suppresses or hides safely. |
| Debug overlay | Unrun | Use the F2 menu/debug control; confirm state, target display, frame, interaction flags, collection behavior, suppression reason, and recovery result are visible. |
| No-notch hardware fallback | Unrun / hardware unavailable | Automated coverage passes. Manual proof requires a built-in no-notch Mac; do not treat the physical-notch host as fallback evidence. |
| Boring-style shape and morph | Unrun | On a physical-notch Mac, verify the custom top shoulder is inset rather than a rounded rectangle; verify closed `6/14` to expanded `19/24` radii, top seam, shadow, and no frame jump. |
| Host settle and rapid reopen | Unrun | Expand, collapse, then reopen before the close spring settles. Confirm the old settle task does not shrink the reopened `640 × 210 pt` host. |
| Reduced Motion | Unrun | Enable Reduce Motion and confirm the state change remains understandable with a short non-spring transition and no overshoot. |

## F2 gate decision

Automated F2 verification is **passed**. The F2 native manual gate is **pending human QA**. The
remaining evidence is deliberately not claimed as passed: it requires an accessibility-enabled
interactive session or a tester operating the built Debug app through the matrix above.
