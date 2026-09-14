import Foundation
import NotchCore
import NotchDomain
import NotchSurface
import Testing

@Test("Geometry targets the built-in physical notch instead of the main external display")
func anchorsGeometryToBuiltInPhysicalNotch() {
    let external = ScreenTopology.Screen(
        identifier: "external-main",
        isBuiltIn: false,
        frame: CGRect(x: -1200, y: 0, width: 1200, height: 900),
        visibleFrame: CGRect(x: -1200, y: 0, width: 1200, height: 860),
        scale: 1
    )
    let builtIn = ScreenTopology.Screen(
        identifier: "built-in",
        isBuiltIn: true,
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 942),
        physicalNotchFrame: CGRect(x: 648, y: 946, width: 216, height: 36),
        scale: 2
    )

    let geometry = NotchSurfaceGeometry.frame(
        for: SurfaceExpansionContract.hostSize,
        in: .init(screens: [external, builtIn])
    )

    #expect(geometry?.screenIdentifier == builtIn.identifier)
    #expect(geometry?.frame.midX == builtIn.physicalNotchFrame?.midX)
    // The fixed native host reaches the real display top. The visible surface
    // then morphs inside it without moving the host between states.
    #expect(geometry?.frame.maxY == builtIn.frame.maxY)
    #expect(geometry?.frame.size == SurfaceExpansionContract.hostSize)
    #expect(geometry.map { builtIn.frame.contains($0.frame) } == true)
}

@Test("Geometry uses a contained top-center fallback for a built-in display without a valid notch")
func fallsBackSafelyWhenPhysicalNotchIsMissingOrInvalid() {
    let builtIn = ScreenTopology.Screen(
        identifier: "built-in",
        isBuiltIn: true,
        frame: CGRect(x: 40, y: 20, width: 1440, height: 900),
        visibleFrame: CGRect(x: 40, y: 20, width: 1440, height: 860),
        physicalNotchFrame: CGRect(x: -1, y: 0, width: 1, height: 1),
        scale: 2
    )

    let geometry = NotchSurfaceGeometry.frame(
        for: .init(width: 220, height: 52),
        in: .init(screens: [builtIn])
    )

    #expect(geometry?.screenIdentifier == builtIn.identifier)
    #expect(geometry.map { builtIn.frame.contains($0.frame) } == true)
    #expect(geometry?.frame.midX == builtIn.visibleFrame.midX)
}

@Test("Collapsed geometry follows the physical notch and preserves fixed expanded sizes")
func derivesCollapsedSizeAndExposesFixedExpandedSurfaceSizes() {
    let physicalNotch = CGRect(x: 648, y: 946, width: 216, height: 36)
    let notchedDisplay = ScreenTopology.Screen(
        identifier: "built-in",
        isBuiltIn: true,
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 942),
        physicalNotchFrame: physicalNotch,
        scale: 2
    )
    let noNotchDisplay = ScreenTopology.Screen(
        identifier: "built-in",
        isBuiltIn: true,
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 942),
        scale: 2
    )

    #expect(NotchSurfaceGeometry.collapsedSize(in: .init(screens: [notchedDisplay])) == CGSize(width: 220, height: 36))
    #expect(NotchSurfaceGeometry.collapsedSize(in: .init(screens: [noNotchDisplay])) == CGSize(width: 185, height: 32))
    #expect(SurfaceExpansionContract.surfaceSize == CGSize(width: 640, height: 190))
    #expect(SurfaceExpansionContract.hostSize == CGSize(width: 640, height: 210))
}

@Test("Native hit testing excludes the transparent shape envelope")
func nativeHitTestingFollowsVisibleSurfaceShape() {
    let hostSize = SurfaceExpansionContract.hostSize
    let surfaceSize = SurfaceExpansionContract.surfaceSize

    #expect(
        NotchSurfaceHitTesting.contains(
            point: CGPoint(x: 320, y: 80), hostSize: hostSize, surfaceSize: surfaceSize,
            topShoulderRadius: 19, bottomCornerRadius: 24))
    #expect(
        !NotchSurfaceHitTesting.contains(
            point: CGPoint(x: 2, y: 2), hostSize: hostSize, surfaceSize: surfaceSize,
            topShoulderRadius: 19, bottomCornerRadius: 24))
    #expect(
        !NotchSurfaceHitTesting.contains(
            point: CGPoint(x: 320, y: 202), hostSize: hostSize, surfaceSize: surfaceSize,
            topShoulderRadius: 19, bottomCornerRadius: 24))
}

@Test("Geometry suppresses unavailable or invalid built-in displays and reframes changed topology")
func suppressesInvalidTopologiesAndReframesAfterScaleChange() {
    let externalOnly = ScreenTopology.Screen(
        identifier: "external",
        isBuiltIn: false,
        frame: CGRect(x: 0, y: 0, width: 1000, height: 700),
        visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 660),
        scale: 1
    )
    let invalidBuiltIn = ScreenTopology.Screen(
        identifier: "invalid-built-in",
        isBuiltIn: true,
        frame: .zero,
        visibleFrame: .zero,
        scale: 2
    )
    #expect(NotchSurfaceGeometry.frame(for: .init(width: 136, height: 46), in: .init(screens: [externalOnly])) == nil)
    #expect(NotchSurfaceGeometry.frame(for: .init(width: 136, height: 46), in: .init(screens: [invalidBuiltIn])) == nil)

    let original = ScreenTopology.Screen(
        identifier: "built-in",
        isBuiltIn: true,
        frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 860),
        scale: 2
    )
    let changed = ScreenTopology.Screen(
        identifier: original.identifier,
        isBuiltIn: true,
        frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
        visibleFrame: CGRect(x: 0, y: 0, width: 1728, height: 1072),
        scale: 1
    )
    let size = CGSize(width: 320, height: 160)
    let originalGeometry = NotchSurfaceGeometry.frame(for: size, in: .init(screens: [original]))
    let changedGeometry = NotchSurfaceGeometry.frame(for: size, in: .init(screens: [changed]))

    #expect(originalGeometry.map { original.frame.contains($0.frame) } == true)
    #expect(changedGeometry.map { changed.frame.contains($0.frame) } == true)
    #expect(originalGeometry?.frame != changedGeometry?.frame)
}

@Test("Display revalidation keeps valid geometry visible and suppresses a detached built-in display")
@MainActor
func revalidatesDisplayGeometryThroughTheCoordinatorSeam() {
    let validPanel = RecordingSurfacePanel(revalidationSucceeds: true)
    let validCoordinator = SurfaceCoordinator(panel: validPanel)
    _ = validCoordinator.handle(.showCollapsed)
    validPanel.sendDisplayChange()
    #expect(validPanel.revalidationCount == 1)
    #expect(validCoordinator.snapshot.state == .collapsed)

    let detachedPanel = RecordingSurfacePanel(revalidationSucceeds: false)
    let detachedScheduler = RecordingSurfaceScheduler()
    let detachedCoordinator = SurfaceCoordinator(panel: detachedPanel, scheduler: detachedScheduler)
    _ = detachedCoordinator.handle(.showCollapsed)
    detachedPanel.sendDisplayChange()
    #expect(detachedPanel.revalidationCount == 1)
    #expect(detachedCoordinator.snapshot.state == .recovering)
    #expect(detachedPanel.effects == [.showCollapsed, .suppress])
    detachedPanel.setRevalidationSucceeds(true)
    detachedScheduler.fireLatest()
    #expect(detachedCoordinator.snapshot.state == .collapsed)
    #expect(detachedPanel.effects == [.showCollapsed, .suppress, .showCollapsed])
}

@Test("Context policy suppresses full-screen work and always returns to collapsed")
@MainActor
func suppressesFullScreenWithoutRestoringExpandedState() {
    let panel = RecordingSurfacePanel()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: RecordingSurfaceScheduler())

    _ = coordinator.handle(.showCollapsed)
    _ = coordinator.handle(.clicked)
    #expect(coordinator.snapshot.state == .expanded)

    _ = coordinator.handle(.fullScreenPolicyEngaged)
    #expect(coordinator.snapshot.state == .suppressed)
    #expect(coordinator.snapshot.suppressionReason == .fullScreen)

    _ = coordinator.handle(.fullScreenPolicyCleared)
    #expect(coordinator.snapshot.state == .collapsed)
    #expect(coordinator.snapshot.suppressionReason == nil)
    #expect(panel.effects == [.showCollapsed, .showExpanded(focus: true), .suppress, .showCollapsed])
}

@Test("A Space policy update never opens a user-hidden surface")
@MainActor
func keepsHiddenSurfaceHiddenWhenFullScreenContextClears() {
    let panel = RecordingSurfacePanel()
    let coordinator = SurfaceCoordinator(panel: panel)

    _ = coordinator.handle(.fullScreenPolicyEngaged)
    _ = coordinator.handle(.fullScreenPolicyCleared)

    #expect(coordinator.snapshot.state == .hidden)
    #expect(panel.effects == [])
}

@Test("Wake and unlock cannot recover through an active full-screen suppression")
@MainActor
func retainsFullScreenSuppressionAcrossContextRecovery() {
    let panel = RecordingSurfacePanel()
    let scheduler = RecordingSurfaceScheduler()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler)

    _ = coordinator.handle(.showCollapsed)
    _ = coordinator.handle(.fullScreenPolicyEngaged)
    _ = coordinator.handle(.willSleep)
    _ = coordinator.handle(.didWake)
    _ = coordinator.handle(.sessionLocked)
    _ = coordinator.handle(.sessionUnlocked)

    #expect(coordinator.snapshot.state == .suppressed)
    #expect(coordinator.snapshot.suppressionReason == .fullScreen)
    #expect(panel.effects.filter { $0 == .showCollapsed }.count == 1)
}

@Test("Unlock restores the prior expanded interaction after safe geometry revalidation")
@MainActor
func restoresPriorStateAfterLockWithoutCreatingDuplicateRecovery() {
    let panel = RecordingSurfacePanel()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: RecordingSurfaceScheduler())

    _ = coordinator.handle(.showCollapsed)
    _ = coordinator.handle(.clicked)
    _ = coordinator.handle(.sessionLocked)
    _ = coordinator.handle(.sessionUnlocked)

    #expect(coordinator.snapshot.state == .expanded)
    #expect(coordinator.snapshot.isInteractionPaused == false)
}

@Test("Wake recovery retries once after the F2 backoff then hides with a warning")
@MainActor
func boundsRecoveryAndKeepsTheMenuBarRecoverySeamAvailable() {
    let panel = RecordingSurfacePanel(revalidationSucceeds: false)
    let scheduler = RecordingSurfaceScheduler()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler)

    _ = coordinator.handle(.showCollapsed)
    _ = coordinator.handle(.willSleep)
    #expect(coordinator.snapshot.isInteractionPaused)
    _ = coordinator.handle(.didWake)
    #expect(coordinator.snapshot.state == .recovering)
    #expect(coordinator.snapshot.recoveryAttemptCount == 1)
    #expect(scheduler.scheduledDelays == [.milliseconds(250)])

    scheduler.fireLatest()
    #expect(coordinator.snapshot.state == .hidden)
    #expect(coordinator.snapshot.recoveryAttemptCount == 2)
    #expect(coordinator.snapshot.recoveryOutcome == .failed)
    #expect(coordinator.snapshot.warning == .recoveryFailed)
    #expect(panel.effects == [.showCollapsed, .pauseInteraction, .suppress, .hide])

    let appShell = AppCoordinator(surfaceController: coordinator)
    #expect(appShell.perform(.openDiagnostics) == .placeholderSceneUnavailable(.diagnostics))
}

@Test("Unlock and display invalidation share one recovery without duplicate work")
@MainActor
func coalescesContextRecoveryAndPublishesF2DebugState() {
    let panel = RecordingSurfacePanel(revalidationSucceeds: false)
    let scheduler = RecordingSurfaceScheduler()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler)

    _ = coordinator.handle(.showCollapsed)
    _ = coordinator.handle(.sessionLocked)
    _ = coordinator.handle(.sessionUnlocked)
    _ = coordinator.handle(.displayInvalidated)

    #expect(coordinator.snapshot.state == .recovering)
    #expect(coordinator.snapshot.recoveryAttemptCount == 1)
    #expect(scheduler.scheduledDelays == [.milliseconds(250)])
    #expect(panel.debugSnapshots.last?.state == .recovering)
    #expect(panel.debugSnapshots.last?.isInteractionPaused == false)
}

@Test("App shell exposes safe menu-bar recovery outcomes")
@MainActor
func exposesSafeMenuBarRecoveryOutcomes() {
    let coordinator = AppCoordinator()

    #expect(coordinator.snapshot.isRunning == false)
    #expect(coordinator.start() == .started)
    #expect(coordinator.start() == .alreadyRunning)
    #expect(coordinator.perform(.toggleNotchSurface) == .unavailable(.notchSurface))
    #expect(coordinator.perform(.showDemoState) == .unavailable(.demoState))
    #expect(coordinator.perform(.restartAppShell) == .restarted)
    #expect(coordinator.perform(.quit) == .quitRequested)
    #expect(coordinator.snapshot.isRunning == false)
    #expect(coordinator.snapshot.startCount == 2)
}

@Test("App shell routes the menu toggle through the Notch surface seam")
@MainActor
func routesMenuToggleThroughSurfaceSeam() {
    let surface = RecordingSurfaceToggleController(results: [.shownCollapsed, .hidden])
    let coordinator = AppCoordinator(surfaceController: surface)

    #expect(coordinator.perform(.toggleNotchSurface) == .notchSurfaceToggled(.collapsed))
    #expect(coordinator.perform(.toggleNotchSurface) == .notchSurfaceToggled(.hidden))
    #expect(surface.toggleCount == 2)
}

@Test("App shell remains usable when the Notch surface cannot be created")
@MainActor
func retainsRecoveryPathWhenSurfaceIsUnavailable() {
    let surface = RecordingSurfaceToggleController(results: [.unavailable])
    let presenter = RecordingScenePresenter()
    let coordinator = AppCoordinator(scenePresenter: presenter, surfaceController: surface)

    #expect(coordinator.perform(.toggleNotchSurface) == .unavailable(.notchSurface))
    #expect(coordinator.perform(.openDiagnostics) == .placeholderSceneRequested(.diagnostics))
}

@Test("Surface coordinator toggles only declared collapsed and hidden states")
@MainActor
func togglesCollapsedSurfaceThroughPanelEffects() {
    let panel = RecordingSurfacePanel()
    let coordinator = SurfaceCoordinator(panel: panel)

    #expect(coordinator.snapshot.state == .hidden)
    #expect(coordinator.handle(.toggle) == .collapsed)
    #expect(coordinator.snapshot.state == .collapsed)
    #expect(panel.effects == [.showCollapsed])
    #expect(coordinator.handle(.toggle) == .hidden)
    #expect(panel.effects == [.showCollapsed, .hide])
}

@Test("Surface coordinator rejects an undeclared transition without panel effects")
@MainActor
func rejectsUndeclaredSurfaceTransition() {
    let panel = RecordingSurfacePanel()
    let coordinator = SurfaceCoordinator(panel: panel)

    #expect(coordinator.handle(.hide) == .hidden)
    #expect(coordinator.snapshot.state == .hidden)
    #expect(panel.effects == [])
}

@Test("Surface coordinator reports an unavailable panel without changing state")
@MainActor
func reportsUnavailablePanelCreation() {
    let panel = RecordingSurfacePanel(succeeds: false)
    let coordinator = SurfaceCoordinator(panel: panel)

    #expect(coordinator.toggleNotchSurface() == .unavailable)
    #expect(coordinator.snapshot.state == .hidden)
    #expect(panel.effects == [.showCollapsed])
}

@Test("Surface interaction expands only after the F2 hover delay within its bounded trigger")
@MainActor
func expandsAfterBoundedHoverDelay() {
    let panel = RecordingSurfacePanel()
    let scheduler = RecordingSurfaceScheduler()
    let configuration = SurfaceInteractionConfiguration(
        hoverDelay: .milliseconds(42),
        autoCollapseDelay: .seconds(7)
    )
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler, configuration: configuration)

    #expect(coordinator.handle(.showCollapsed) == .collapsed)
    #expect(coordinator.handle(.hoverEntered) == .collapsed)
    #expect(scheduler.scheduledDelays == [configuration.hoverDelay])
    scheduler.fireLatest()
    #expect(coordinator.snapshot.state == .expanded)
    #expect(panel.effects == [.showCollapsed, .showExpanded(focus: false)])
}

@Test("Hover uses a 300 ms dwell and 100 ms exit grace")
@MainActor
func hoverUsesDwellAndGraceWithoutFlicker() {
    let panel = RecordingSurfacePanel()
    let scheduler = RecordingSurfaceScheduler()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler)

    _ = coordinator.handle(.showCollapsed)
    _ = coordinator.handle(.hoverEntered)
    #expect(scheduler.scheduledDelays == [SurfaceInteractionDefaults.hoverDelay])
    scheduler.fireLatest()
    #expect(coordinator.snapshot.state == .expanded)

    _ = coordinator.handle(.expandedHoverExited)
    #expect(scheduler.scheduledDelays.last == SurfaceInteractionDefaults.hoverCloseGrace)
    _ = coordinator.handle(.expandedHoverEntered)
    scheduler.fireLatest()
    #expect(coordinator.snapshot.state == .expanded)
}

@Test("Interaction holds defer hover close and final release restarts grace outside")
@MainActor
func interactionHoldsDeferHoverClose() {
    let panel = RecordingSurfacePanel()
    let scheduler = RecordingSurfaceScheduler()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler)

    _ = coordinator.handle(.showCollapsed)
    _ = coordinator.handle(.hoverEntered)
    scheduler.fireLatest()
    _ = coordinator.handle(.expandedHoverExited)
    let lease = coordinator.acquireInteractionHold(.keyboardFocus)
    #expect(lease != nil)
    scheduler.fireLatest()
    #expect(coordinator.snapshot.state == .expanded)
    lease?.release()
    #expect(scheduler.scheduledDelays.last == SurfaceInteractionDefaults.hoverCloseGrace)
    scheduler.fireLatest()
    #expect(coordinator.snapshot.state == .collapsed)
}

@Test("Every interaction hold kind suppresses close and stale releases are harmless")
@MainActor
func interactionHoldKindsAreTypedAndSessionScoped() {
    let panel = RecordingSurfacePanel()
    let scheduler = RecordingSurfaceScheduler()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler)

    for kind in SurfaceInteractionHoldKind.allCases {
        _ = coordinator.handle(.showCollapsed)
        _ = coordinator.handle(.clicked)
        let lease = coordinator.acquireInteractionHold(kind)
        #expect(lease != nil)
        _ = coordinator.handle(.escapePressed)
        lease?.release()
        #expect(coordinator.snapshot.state == .collapsed)
    }

    _ = coordinator.handle(.clicked)
    let stale = coordinator.acquireInteractionHold(.drag)
    _ = coordinator.handle(.escapePressed)
    _ = coordinator.handle(.clicked)
    stale?.release()
    _ = coordinator.handle(.autoCollapseElapsed)
    #expect(coordinator.snapshot.state == .collapsed)
}

@Test("Suppression and recovery invalidate interaction holds and close work")
@MainActor
func invalidatesHoldsAcrossSuppressionAndRecovery() {
    let panel = RecordingSurfacePanel(revalidationSucceeds: false)
    let scheduler = RecordingSurfaceScheduler()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler)

    _ = coordinator.handle(.showCollapsed)
    _ = coordinator.handle(.hoverEntered)
    scheduler.fireLatest()
    _ = coordinator.handle(.expandedHoverExited)
    let suppressedLease = coordinator.acquireInteractionHold(.accessibilityInteraction)
    _ = coordinator.handle(.fullScreenPolicyEngaged)
    suppressedLease?.release()
    scheduler.fireLatest()
    #expect(coordinator.snapshot.state == .suppressed)

    _ = coordinator.handle(.fullScreenPolicyCleared)
    _ = coordinator.handle(.clicked)
    let recoveringLease = coordinator.acquireInteractionHold(.confirmation)
    _ = coordinator.handle(.displayInvalidated)
    recoveringLease?.release()
    #expect(coordinator.snapshot.state == .recovering)
    #expect(scheduler.scheduledDelays.last == SurfaceInteractionDefaults.recoveryBackoff)
}

@Test("Click and keyboard origins retain bounded inactivity instead of hover grace")
@MainActor
func deliberateOriginsRetainInactivityPolicy() {
    let panel = RecordingSurfacePanel()
    let scheduler = RecordingSurfaceScheduler()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler)

    _ = coordinator.handle(.showCollapsed)
    _ = coordinator.handle(.clicked)
    _ = coordinator.handle(.expandedHoverExited)
    #expect(scheduler.scheduledDelays.last == SurfaceInteractionDefaults.autoCollapseDelay)
    scheduler.fireLatest()
    #expect(coordinator.snapshot.state == .collapsed)
}

@Test("Surface interaction cancels hover and collapses through its documented exits")
@MainActor
func cancelsHoverAndCollapsesThroughSafeExits() {
    let panel = RecordingSurfacePanel()
    let scheduler = RecordingSurfaceScheduler()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler)

    _ = coordinator.handle(.showCollapsed)
    _ = coordinator.handle(.hoverEntered)
    _ = coordinator.handle(.hoverExited)
    scheduler.fireLatest()
    #expect(coordinator.snapshot.state == .collapsed)

    #expect(coordinator.handle(.clicked) == .expanded)
    #expect(coordinator.handle(.escapePressed) == .collapsed)
    #expect(coordinator.handle(.clicked) == .expanded)
    #expect(coordinator.handle(.clickedOutside) == .collapsed)
    #expect(
        panel.effects == [
            .showCollapsed,
            .showExpanded(focus: true),
            .showCollapsed,
            .showExpanded(focus: true),
            .showCollapsed,
        ])
}

@Test("Surface interaction resets but does not persist the F2 auto-collapse default")
@MainActor
func resetsAutoCollapseAfterExpandedInteraction() {
    let panel = RecordingSurfacePanel()
    let scheduler = RecordingSurfaceScheduler()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler)

    _ = coordinator.handle(.showCollapsed)
    #expect(coordinator.handle(.clicked) == .expanded)
    #expect(scheduler.scheduledDelays == [SurfaceInteractionDefaults.autoCollapseDelay])
    _ = coordinator.handle(.interaction)
    #expect(
        scheduler.scheduledDelays == [
            SurfaceInteractionDefaults.autoCollapseDelay,
            SurfaceInteractionDefaults.autoCollapseDelay,
        ])
    scheduler.fire(at: 0)
    #expect(coordinator.snapshot.state == .expanded)
    scheduler.fireLatest()
    #expect(coordinator.snapshot.state == .collapsed)
}

@Test("Expanded hover pauses auto-collapse and compact remains passive until clicked")
@MainActor
func pausesExpandedHoverAndExpandsCompactOnClick() {
    let panel = RecordingSurfacePanel()
    let scheduler = RecordingSurfaceScheduler()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler)

    _ = coordinator.handle(.showCollapsed)
    #expect(coordinator.handle(.showCompact) == .compact)
    #expect(panel.effects == [.showCollapsed, .showCompact])
    #expect(coordinator.handle(.clicked) == .expanded)
    _ = coordinator.handle(.expandedHoverEntered)
    scheduler.fireLatest()
    #expect(coordinator.snapshot.state == .expanded)
    _ = coordinator.handle(.expandedHoverExited)
    scheduler.fireLatest()
    #expect(coordinator.snapshot.state == .collapsed)
}

@Test("Hidden and suppressed surfaces expose no pointer target")
@MainActor
func rejectsPointerInteractionWhileUnavailable() {
    let panel = RecordingSurfacePanel()
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: RecordingSurfaceScheduler())

    #expect(coordinator.handle(.hoverEntered) == .hidden)
    #expect(coordinator.handle(.clicked) == .hidden)
    #expect(coordinator.handle(.suppressed) == .suppressed)
    #expect(coordinator.handle(.hoverEntered) == .suppressed)
    #expect(coordinator.handle(.clicked) == .suppressed)
    #expect(panel.effects == [.suppress])
}

@Test("Surface coordinator receives native input through an injectable monitor seam")
@MainActor
func receivesInputThroughMonitorSeam() {
    let panel = RecordingSurfacePanel()
    let input = RecordingSurfaceInput()
    let coordinator = SurfaceCoordinator(panel: panel, input: input)

    _ = coordinator.handle(.showCollapsed)
    input.send(.clicked)
    #expect(coordinator.snapshot.state == .expanded)
}

@Test("Expansion admission keeps undersized valid topology out of recovery")
@MainActor
func rejectsUnsupportedExpandedCapacityWithoutRecovery() {
    let panel = RecordingSurfacePanel()
    let scheduler = RecordingSurfaceScheduler()
    let admission = RecordingExpansionAdmission(
        availability: .unsupportedCapacity(topologyRevision: 7)
    )
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler, admission: admission)

    _ = coordinator.handle(.showCollapsed)
    #expect(coordinator.handle(.hoverDelayElapsed) == .collapsed)
    #expect(coordinator.snapshot.expandedAvailability == .unsupportedCapacity(topologyRevision: 7))
    #expect(coordinator.snapshot.admissionFeedback == nil)
    #expect(coordinator.diagnostics.events == [.unsupportedExpandedCapacity(topologyRevision: 7)])

    #expect(coordinator.handle(.clicked) == .collapsed)
    #expect(coordinator.snapshot.admissionFeedback == .expandedUnavailable(topologyRevision: 7))
    #expect(coordinator.snapshot.state != .recovering)
    #expect(panel.effects == [.showCollapsed])
    #expect(scheduler.scheduledDelays == [SurfaceInteractionDefaults.admissionFeedbackDuration])
    scheduler.fireLatest()
    #expect(coordinator.snapshot.admissionFeedback == nil)
}

@Test("Topology revision refreshes admission feedback and permits a later fixed host")
@MainActor
func refreshesExpandedAvailabilityForTheCurrentTopologyRevision() {
    let panel = RecordingSurfacePanel()
    let admission = RecordingExpansionAdmission(
        availability: .unsupportedCapacity(topologyRevision: 3)
    )
    let coordinator = SurfaceCoordinator(panel: panel, admission: admission)

    _ = coordinator.handle(.showCollapsed)
    _ = coordinator.handle(.clicked)
    #expect(coordinator.snapshot.admissionFeedback == .expandedUnavailable(topologyRevision: 3))

    admission.availability = .available(topologyRevision: 4)
    _ = coordinator.handle(.displayInvalidated)
    #expect(coordinator.snapshot.expandedAvailability == .available(topologyRevision: 4))
    #expect(coordinator.snapshot.admissionFeedback == nil)

    #expect(coordinator.handle(.keyboardRequestedExpansion) == .expanded)
    #expect(coordinator.snapshot.expandedAvailability == .available(topologyRevision: 4))
    #expect(coordinator.snapshot.admissionFeedback == nil)
    #expect(panel.effects == [.showCollapsed, .suppress, .showCollapsed, .showExpanded(focus: true)])
}

@Test("Invalid topology enters F2 recovery instead of becoming an admission rejection")
@MainActor
func recoversFromInvalidExpandedTopology() {
    let panel = RecordingSurfacePanel(revalidationSucceeds: false)
    let scheduler = RecordingSurfaceScheduler()
    let admission = RecordingExpansionAdmission(availability: .invalidTopology(topologyRevision: 9))
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler, admission: admission)

    _ = coordinator.handle(.showCollapsed)
    #expect(coordinator.handle(.clicked) == .recovering)
    #expect(coordinator.snapshot.expandedAvailability == .invalidTopology(topologyRevision: 9))
    #expect(coordinator.snapshot.admissionFeedback == nil)
    #expect(coordinator.diagnostics.events == [.invalidExpandedTopology(topologyRevision: 9)])
    #expect(panel.effects == [.showCollapsed, .suppress])
}

@Test("Native expanded-panel failure enters F2 recovery after successful admission")
@MainActor
func recoversWhenNativeExpandedPanelApplyFails() {
    let panel = FailingExpandedSurfacePanel()
    let scheduler = RecordingSurfaceScheduler()
    let admission = RecordingExpansionAdmission(availability: .available(topologyRevision: 5))
    let coordinator = SurfaceCoordinator(panel: panel, scheduler: scheduler, admission: admission)

    _ = coordinator.handle(.showCollapsed)
    #expect(coordinator.handle(.clicked) == .recovering)
    #expect(coordinator.snapshot.expandedAvailability == .available(topologyRevision: 5))
    #expect(coordinator.diagnostics.events == [.nativeExpandedPanelFailure])
    #expect(panel.effects == [.showCollapsed, .showExpanded(focus: true), .suppress])
}

@Test("Expanded placeholder routes only its explicit detail action without changing surface state")
@MainActor
func routesExplicitDetailNavigationOutsideSurfaceState() {
    let panel = RecordingSurfacePanel()
    let input = RecordingSurfaceInput()
    let detailWindow = RecordingDetailWindow()
    let detail = DetailWindowCoordinator(window: detailWindow)
    let coordinator = SurfaceCoordinator(panel: panel, input: input, detailNavigator: detail)

    _ = coordinator.handle(.showCollapsed)
    _ = coordinator.handle(.clicked)
    input.sendDetail(.placeholder)

    #expect(detailWindow.presentedRequests == [.placeholder])
    #expect(coordinator.snapshot.state == .expanded)
    detailWindow.simulateUserClose()
    #expect(coordinator.snapshot.state == .expanded)
    #expect(SurfaceState.allCases.contains(coordinator.snapshot.state))
}

@Test("Detail coordinator reuses the matching window and closes independently")
@MainActor
func reusesAndClosesDetailWindowIndependently() {
    let window = RecordingDetailWindow()
    let coordinator = DetailWindowCoordinator(window: window)

    #expect(coordinator.open(.placeholder) == .opened)
    #expect(coordinator.open(.placeholder) == .focused)
    #expect(window.presentedRequests == [.placeholder])
    #expect(window.focusCount == 2)
    window.simulateUserClose()
    #expect(coordinator.open(.placeholder) == .opened)
    #expect(window.presentedRequests == [.placeholder, .placeholder])
    #expect(coordinator.close() == .closed)
    #expect(coordinator.close() == .alreadyClosed)
    #expect(window.closeCount == 1)
}

@Test("App shell requests independent placeholder scenes")
@MainActor
func requestsIndependentPlaceholderScenes() {
    let presenter = RecordingScenePresenter()
    let coordinator = AppCoordinator(scenePresenter: presenter)

    #expect(coordinator.perform(.openSettings) == .placeholderSceneRequested(.settings))
    #expect(coordinator.perform(.openDiagnostics) == .placeholderSceneRequested(.diagnostics))
    #expect(presenter.presentedScenes == [.settings, .diagnostics])
}

@Test("A failed placeholder scene request does not block the other scene")
@MainActor
func isolatesPlaceholderScenePresentationFailures() {
    let presenter = SelectiveScenePresenter(unavailableScenes: [.settings])
    let coordinator = AppCoordinator(scenePresenter: presenter)

    #expect(coordinator.perform(.openSettings) == .placeholderSceneUnavailable(.settings))
    #expect(coordinator.perform(.openDiagnostics) == .placeholderSceneRequested(.diagnostics))
    #expect(presenter.requestedScenes == [.settings, .diagnostics])
}

@Test("App shell keeps its menu-bar resources safe through lifecycle delivery and termination")
@MainActor
func handlesLifecycleWithoutStartingLaterPhaseInfrastructure() {
    let lifecycle = RecordingLifecycleObserver()
    let coordinator = AppCoordinator(lifecycleObserver: lifecycle)

    #expect(coordinator.start() == .started)
    #expect(lifecycle.startCount == 1)

    lifecycle.send(.activated)
    #expect(coordinator.snapshot.lifecycleState == .running)
    lifecycle.send(.deactivated)
    #expect(coordinator.snapshot.lifecycleState == .inactive)
    lifecycle.send(.willSleep)
    #expect(coordinator.snapshot.lifecycleState == .sleeping)
    lifecycle.send(.didWake)
    #expect(coordinator.snapshot.lifecycleState == .running)
    lifecycle.send(.locked)
    #expect(coordinator.snapshot.lifecycleState == .locked)
    lifecycle.send(.unlocked)
    #expect(coordinator.snapshot.lifecycleState == .running)
    #expect(coordinator.snapshot.isRunning)

    lifecycle.send(.willTerminate)
    #expect(coordinator.snapshot.isRunning == false)
    #expect(coordinator.snapshot.lifecycleState == .stopped)
    #expect(lifecycle.stopCount == 1)
    let deliveredEventCount = lifecycle.deliveredEvents.count
    lifecycle.send(.activated)
    #expect(lifecycle.deliveredEvents.count == deliveredEventCount)

    #expect(coordinator.start() == .started)
    #expect(lifecycle.startCount == 2)
    #expect(coordinator.perform(.restartAppShell) == .restarted)
    #expect(lifecycle.stopCount == 2)
    #expect(lifecycle.startCount == 3)
    #expect(coordinator.perform(.quit) == .quitRequested)
    #expect(lifecycle.stopCount == 3)
}

@Test("App shell forwards lifecycle and F2 debug requests only to an available Notch surface")
@MainActor
func forwardsF2ContextAndDebugControlsThroughTheAppShellSeam() {
    let lifecycle = RecordingLifecycleObserver()
    let surface = RecordingSurfaceLifecycleController()
    let coordinator = AppCoordinator(lifecycleObserver: lifecycle, surfaceController: surface)

    _ = coordinator.start()
    lifecycle.send(.willSleep)
    lifecycle.send(.didWake)
    #expect(surface.lifecycleEvents == [.willSleep, .didWake])
    #expect(coordinator.perform(.toggleSurfaceDebugOverlay) == .surfaceDebugOverlayToggled)
    #expect(surface.debugToggleCount == 1)
}

@Test("App shell snapshots launch-at-login status through an injected adapter")
@MainActor
func snapshotsLaunchAtLoginStatusWithoutRegistration() {
    for status in LaunchAtLoginStatus.allCases {
        let coordinator = AppCoordinator(launchAtLoginController: FixedLaunchAtLoginController(value: status))

        #expect(coordinator.start() == .started)
        #expect(coordinator.snapshot.launchAtLoginStatus == status)
    }
}

@Test("NotchDomain encodes a typed Action, Module, and Event envelope")
func encodesPureDomainContracts() throws {
    let action = try #require(ActionID("app.openSettings"))
    let module = try #require(ModuleID("demo.module"))
    let event = try EventEnvelope(
        version: 1,
        source: module.rawValue,
        type: "demo.status.changed",
        timestamp: Date(timeIntervalSince1970: 0),
        payload: ["status": "ready"]
    )

    let encoded = try JSONEncoder().encode(event)
    let decoded = try JSONDecoder().decode(EventEnvelope<[String: String]>.self, from: encoded)
    let encodedObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

    #expect(action.rawValue == "app.openSettings")
    #expect(decoded.source == module.rawValue)
    #expect(decoded.type == "demo.status.changed")
    #expect(decoded.priority == .normal)
    #expect(encodedObject["timestamp"] as? String == "1970-01-01T00:00:00Z")
    #expect(SurfaceState.allCases == [.hidden, .collapsed, .compact, .expanded, .suppressed, .recovering])
    #expect(Capability("calendar.read")?.rawValue == "calendar.read")
    #expect(ActionID("shell.executeRaw") == nil)
    #expect(ActionDefinition(id: action, title: "Open Settings").id == action)
    #expect(DemoModule(id: module).metadata.capabilities == [])
}

@Test("NotchDomain rejects malformed decoded contracts")
func rejectsMalformedDecodedContracts() {
    let invalidAction = Data("\"shell.executeRaw\"".utf8)
    let invalidEvent = Data(
        """
        {"id":"00000000-0000-0000-0000-000000000000","version":0,"source":"demo.module","type":"demo.status.changed","timestamp":"2026-09-13T01:00:00Z","payload":{}}
        """.utf8
    )

    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(ActionID.self, from: invalidAction)
    }
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(EventEnvelope<EmptyPayload>.self, from: invalidEvent)
    }
}

@Test("NotchDomain rejects malformed identities and envelope versions")
func rejectsMalformedContracts() {
    #expect(ModuleID("Demo") == nil)
    #expect(EventType("demo..changed") == nil)
    #expect(throws: NotchDomainError.invalidEventVersion(0)) {
        try EventEnvelope(
            version: 0,
            source: ModuleID("demo.module")!.rawValue,
            type: "demo.status.changed",
            timestamp: .now,
            payload: EmptyPayload()
        )
    }
}

private struct EmptyPayload: Codable, Sendable {}

@MainActor
private final class RecordingScenePresenter: AppShellScenePresenter {
    private(set) var presentedScenes: [AppShellPlaceholderScene] = []

    func present(_ scene: AppShellPlaceholderScene) -> AppShellScenePresentationResult {
        presentedScenes.append(scene)
        return .presented
    }
}

@MainActor
private final class SelectiveScenePresenter: AppShellScenePresenter {
    let unavailableScenes: Set<AppShellPlaceholderScene>
    private(set) var requestedScenes: [AppShellPlaceholderScene] = []

    init(unavailableScenes: Set<AppShellPlaceholderScene>) {
        self.unavailableScenes = unavailableScenes
    }

    func present(_ scene: AppShellPlaceholderScene) -> AppShellScenePresentationResult {
        requestedScenes.append(scene)
        return unavailableScenes.contains(scene) ? .unavailable : .presented
    }
}

@MainActor
private final class RecordingLifecycleObserver: AppShellLifecycleObserving {
    private var handler: (@MainActor (AppShellLifecycleEvent) -> Void)?
    private(set) var deliveredEvents: [AppShellLifecycleEvent] = []
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start(observing handler: @escaping @MainActor (AppShellLifecycleEvent) -> Void) {
        startCount += 1
        self.handler = handler
    }

    func stop() {
        stopCount += 1
        handler = nil
    }

    func send(_ event: AppShellLifecycleEvent) {
        guard let handler else { return }
        deliveredEvents.append(event)
        handler(event)
    }
}

private struct FixedLaunchAtLoginController: LaunchAtLoginControlling {
    let value: LaunchAtLoginStatus

    func status() -> LaunchAtLoginStatus {
        value
    }
}

@MainActor
private final class RecordingSurfaceToggleController: NotchSurfaceToggling {
    private var results: [NotchSurfaceToggleResult]
    private(set) var toggleCount = 0

    init(results: [NotchSurfaceToggleResult]) {
        self.results = results
    }

    func toggleNotchSurface() -> NotchSurfaceToggleResult {
        toggleCount += 1
        return results.removeFirst()
    }
}

@MainActor
private final class RecordingSurfaceLifecycleController: NotchSurfaceToggling, NotchSurfaceLifecycleHandling,
    NotchSurfaceDebugToggling
{
    private(set) var lifecycleEvents: [AppShellLifecycleEvent] = []
    private(set) var debugToggleCount = 0

    func toggleNotchSurface() -> NotchSurfaceToggleResult { .shownCollapsed }

    func handleAppShellLifecycle(_ event: AppShellLifecycleEvent) {
        lifecycleEvents.append(event)
    }

    func toggleDebugOverlay() -> Bool {
        debugToggleCount += 1
        return true
    }
}

@MainActor
private final class RecordingSurfacePanel: SurfacePanelPresenting, SurfaceGeometryRevalidating,
    SurfaceDebugOverlayPresenting
{
    private let succeeds: Bool
    private var revalidationSucceeds: Bool
    private(set) var effects: [SurfacePanelEffect] = []
    private(set) var revalidationCount = 0
    private(set) var debugSnapshots: [SurfaceSnapshot] = []
    private var displayChangeHandler: (@MainActor () -> Void)?

    init(succeeds: Bool = true, revalidationSucceeds: Bool = true) {
        self.succeeds = succeeds
        self.revalidationSucceeds = revalidationSucceeds
    }

    func apply(_ effect: SurfacePanelEffect) -> Bool {
        effects.append(effect)
        return succeeds
    }

    func setDisplayChangeHandler(_ handler: @escaping @MainActor () -> Void) {
        displayChangeHandler = handler
    }

    func revalidateGeometry() -> Bool {
        revalidationCount += 1
        return revalidationSucceeds
    }

    func setDebugSnapshot(_ snapshot: SurfaceSnapshot) {
        debugSnapshots.append(snapshot)
    }

    func setRevalidationSucceeds(_ succeeds: Bool) {
        revalidationSucceeds = succeeds
    }

    func sendDisplayChange() {
        displayChangeHandler?()
    }
}

@MainActor
private final class RecordingExpansionAdmission: SurfaceExpansionAdmitting {
    var availability: SurfaceExpandedAvailability

    init(availability: SurfaceExpandedAvailability) {
        self.availability = availability
    }

    func expandedAvailability() -> SurfaceExpandedAvailability {
        availability
    }
}

@MainActor
private final class FailingExpandedSurfacePanel: SurfacePanelPresenting, SurfaceGeometryRevalidating {
    private(set) var effects: [SurfacePanelEffect] = []

    func apply(_ effect: SurfacePanelEffect) -> Bool {
        effects.append(effect)
        if case .showExpanded = effect { return false }
        return true
    }

    func setDisplayChangeHandler(_ handler: @escaping @MainActor () -> Void) {}

    func revalidateGeometry() -> Bool { false }
}

@MainActor
private final class RecordingSurfaceScheduler: SurfaceInteractionScheduling {
    private var actions: [() -> Void] = []
    private(set) var scheduledDelays: [Duration] = []

    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> any SurfaceInteractionTask {
        scheduledDelays.append(delay)
        actions.append(action)
        return RecordingSurfaceTask()
    }

    func fireLatest() {
        actions.last?()
    }

    func fire(at index: Int) {
        actions[index]()
    }
}

@MainActor
private final class RecordingSurfaceTask: SurfaceInteractionTask {
    func cancel() {}
}

@MainActor
private final class RecordingSurfaceInput: SurfaceInputMonitoring, DetailNavigationInput {
    private var handler: (@MainActor (SurfaceIntent) -> Void)?
    private var detailHandler: (@MainActor (DetailNavigationRequest) -> Void)?

    func setInteractionHandler(_ handler: @escaping @MainActor (SurfaceIntent) -> Void) {
        self.handler = handler
    }

    func setDetailNavigationHandler(_ handler: @escaping @MainActor (DetailNavigationRequest) -> Void) {
        detailHandler = handler
    }

    func send(_ intent: SurfaceIntent) {
        handler?(intent)
    }

    func sendDetail(_ request: DetailNavigationRequest) {
        detailHandler?(request)
    }
}

@MainActor
private final class RecordingDetailWindow: DetailWindowPresenting {
    private(set) var presentedRequests: [DetailNavigationRequest] = []
    private(set) var focusCount = 0
    private(set) var closeCount = 0
    private var closeHandler: (@MainActor @Sendable () -> Void)?

    func present(_ request: DetailNavigationRequest) {
        presentedRequests.append(request)
    }

    func focus() {
        focusCount += 1
    }

    func close() {
        closeCount += 1
    }

    func setCloseHandler(_ handler: @escaping @MainActor @Sendable () -> Void) {
        closeHandler = handler
    }

    func simulateUserClose() {
        closeHandler?()
    }
}

private struct DemoModule: NotchModule {
    let id: ModuleID
    let metadata = ModuleMetadata(displayName: "Demo")
}
