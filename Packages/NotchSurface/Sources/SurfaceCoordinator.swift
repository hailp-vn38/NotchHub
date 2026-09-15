import Foundation
import NotchCore
import NotchDomain

public enum SurfaceInteractionDefaults {
    public static let hoverDelay: Duration = .milliseconds(300)
    public static let hoverCloseGrace: Duration = .milliseconds(100)
    public static let autoCollapseDelay: Duration = .seconds(3)
    public static let admissionFeedbackDuration: Duration = .seconds(3)
    public static let recoveryBackoff: Duration = .milliseconds(250)
}

public struct SurfaceInteractionConfiguration: Equatable, Sendable {
    public let hoverDelay: Duration
    public let autoCollapseDelay: Duration

    public init(
        hoverDelay: Duration = SurfaceInteractionDefaults.hoverDelay,
        autoCollapseDelay: Duration = SurfaceInteractionDefaults.autoCollapseDelay
    ) {
        self.hoverDelay = hoverDelay
        self.autoCollapseDelay = autoCollapseDelay
    }
}

@MainActor
public final class SurfaceCoordinator: NotchSurfaceLifecycleControlling,
    NotchSurfaceDebugToggling
{
    public private(set) var snapshot = SurfaceSnapshot()
    private let panel: any SurfacePanelPresenting
    private let input: (any SurfaceInputMonitoring)?
    private let geometryInput: (any SurfaceGeometryRevalidating)?
    private let contextInput: (any SurfaceContextObserving)?
    private let admission: (any SurfaceExpansionAdmitting)?
    private let scheduler: any SurfaceInteractionScheduling
    private let configuration: SurfaceInteractionConfiguration
    private var hoverTask: (any SurfaceInteractionTask)?
    private var collapseTask: (any SurfaceInteractionTask)?
    private var hoverGeneration = 0
    private var collapseGeneration = 0
    private var isPointerInside = false
    private var expandedOrigin: SurfaceExpansionOrigin?
    private var interactionSessionGeneration: UInt64 = 0
    private var interactionHolds: [UUID: SurfaceInteractionHoldKind] = [:]
    private var accessibilityInteractionHold: SurfaceInteractionHoldLease?
    private var recoveryTask: (any SurfaceInteractionTask)?
    private var recoveryGeneration = 0
    private var sessionResumeState: SurfaceState?
    private var admissionFeedbackTask: (any SurfaceInteractionTask)?
    private var admissionFeedbackGeneration = 0
    public private(set) var diagnostics = SurfaceDiagnostics()

    public init(
        panel: any SurfacePanelPresenting,
        scheduler: (any SurfaceInteractionScheduling)? = nil,
        configuration: SurfaceInteractionConfiguration = .init(),
        input: (any SurfaceInputMonitoring)? = nil,
        admission: (any SurfaceExpansionAdmitting)? = nil
    ) {
        self.panel = panel
        self.input = input ?? (panel as? any SurfaceInputMonitoring)
        self.geometryInput = panel as? any SurfaceGeometryRevalidating
        self.contextInput = panel as? any SurfaceContextObserving
        self.admission = admission ?? (panel as? any SurfaceExpansionAdmitting)
        self.scheduler = scheduler ?? MainQueueSurfaceScheduler()
        self.configuration = configuration
        self.input?.setInteractionHandler { [weak self] intent in
            _ = self?.handle(intent)
        }
        self.geometryInput?.setDisplayChangeHandler { [weak self] in
            self?.revalidateDisplayGeometry()
        }
        self.contextInput?.setContextChangeHandler { [weak self] intent in
            _ = self?.handle(intent)
        }
        publishDebugSnapshot()
    }

    public func start() {
        guard snapshot.state == .hidden else { return }
        snapshot.state = .collapsed
        beginRecovery()
        publishDebugSnapshot()
    }

    public func stop() {
        cancelHoverExpansion()
        cancelAutoCollapse()
        cancelRecovery()
        interactionHolds.removeAll()
        accessibilityInteractionHold = nil
        _ = panel.apply(.hide)
        snapshot.state = .hidden
        snapshot.isInteractionPaused = false
        publishDebugSnapshot()
    }

    @discardableResult
    public func handle(_ intent: SurfaceIntent) -> SurfaceState {
        defer { publishDebugSnapshot() }
        switch intent {
        case .fullScreenPolicyEngaged where snapshot.state != .hidden:
            snapshot.suppressionReason = .fullScreen
            _ = apply(.suppressed)
            updateTimers(after: .suppressed, state: snapshot.state)
        case .fullScreenPolicyCleared where snapshot.state == .suppressed:
            snapshot.suppressionReason = nil
            _ = apply(.showCollapsed)
            updateTimers(after: .showCollapsed, state: snapshot.state)
        case .willSleep:
            sessionResumeState = nil
            pauseInteraction()
        case .sessionLocked:
            sessionResumeState = snapshot.state
            pauseInteraction()
        case .didWake:
            resumeAndRecover()
        case .displayInvalidated:
            invalidateExpandedAvailability()
            _ = expandedAdmission()
            resumeAndRecover()
        case .sessionUnlocked:
            resumeAndRecover(restoring: sessionResumeState)
            sessionResumeState = nil
        case .hoverEntered:
            isPointerInside = true
            if snapshot.state == .collapsed {
                scheduleHoverExpansion()
            } else if snapshot.state == .expanded {
                cancelAutoCollapse()
            }
        case .hoverExited:
            isPointerInside = false
            cancelHoverExpansion()
            if snapshot.state == .expanded { scheduleCloseForCurrentOrigin() }
        case .clicked where snapshot.state == .expanded:
            expandedOrigin = .deliberate
            scheduleAutoCollapse()
        case .clickedOutside where snapshot.state == .expanded:
            scheduleOutsideClickCollapse()
        case .interaction where snapshot.state == .expanded:
            if !isPointerInside { scheduleCloseForCurrentOrigin() }
        case .accessibilityInteractionBegan where snapshot.state == .expanded:
            if accessibilityInteractionHold == nil {
                accessibilityInteractionHold = acquireInteractionHold(.accessibilityInteraction)
            }
        case .accessibilityInteractionEnded:
            accessibilityInteractionHold?.release()
            accessibilityInteractionHold = nil
        case .autoCollapseElapsed where snapshot.state == .expanded:
            guard interactionHolds.isEmpty, !isPointerInside else { return snapshot.state }
            guard let state = apply(intent) else { return snapshot.state }
            updateTimers(after: intent, state: state)
        default:
            guard let state = apply(intent) else { return snapshot.state }
            updateTimers(after: intent, state: state)
        }
        return snapshot.state
    }

    /// Acquires a session-scoped hold that prevents hover/inactivity collapse.
    public func acquireInteractionHold(_ kind: SurfaceInteractionHoldKind) -> SurfaceInteractionHoldLease? {
        guard snapshot.state == .expanded else { return nil }
        let id = UUID()
        interactionHolds[id] = kind
        cancelAutoCollapse()
        return SurfaceInteractionHoldLease(coordinator: self, id: id, generation: interactionSessionGeneration)
    }

    fileprivate func releaseInteractionHold(id: UUID, generation: UInt64) {
        guard snapshot.state == .expanded, generation == interactionSessionGeneration else { return }
        guard interactionHolds.removeValue(forKey: id) != nil else { return }
        guard interactionHolds.isEmpty, !isPointerInside else { return }
        scheduleCloseForCurrentOrigin()
    }

    public func handleAppShellLifecycle(_ event: AppShellLifecycleEvent) {
        switch event {
        case .willSleep: _ = handle(.willSleep)
        case .didWake: _ = handle(.didWake)
        case .locked: _ = handle(.sessionLocked)
        case .unlocked: _ = handle(.sessionUnlocked)
        case .activated: _ = handle(.displayInvalidated)
        case .deactivated, .willTerminate: break
        }
    }

    public func toggleDebugOverlay() -> Bool {
        guard let overlay = panel as? any SurfaceDebugOverlayToggling else { return false }
        guard overlay.toggleDebugOverlay() else { return false }
        publishDebugSnapshot()
        return true
    }

    private func apply(_ intent: SurfaceIntent) -> SurfaceState? {
        guard let transition = SurfaceStateMachine.transition(from: snapshot.state, for: intent) else { return nil }
        if case .showExpanded = transition.effect {
            switch expandedAdmission() {
            case .available:
                clearAdmissionFeedback()
            case .unsupportedCapacity(let topologyRevision):
                recordDiagnostic(.unsupportedExpandedCapacity(topologyRevision: topologyRevision))
                if intent != .hoverDelayElapsed {
                    showAdmissionFeedback(for: topologyRevision)
                }
                return snapshot.state
            case .invalidTopology(let topologyRevision):
                recordDiagnostic(.invalidExpandedTopology(topologyRevision: topologyRevision))
                beginRecovery()
                return snapshot.state
            case .unknown:
                beginRecovery()
                return snapshot.state
            }
        }
        guard panel.apply(transition.effect) else {
            if case .showExpanded = transition.effect {
                recordDiagnostic(.nativeExpandedPanelFailure)
                beginRecovery()
                return snapshot.state
            }
            return nil
        }
        let wasExpanded = snapshot.state == .expanded
        snapshot.state = transition.state
        if transition.state == .expanded, !wasExpanded {
            interactionSessionGeneration &+= 1
            interactionHolds.removeAll()
            expandedOrigin =
                switch intent {
                case .hoverDelayElapsed: .hover
                default: .deliberate
                }
        } else if wasExpanded, transition.state != .expanded {
            invalidateInteractionSession()
            (panel as? any SurfaceFocusRestoring)?.restoreFocusAfterSurfaceInteraction()
        }
        return snapshot.state
    }

    private func expandedAdmission() -> SurfaceExpandedAvailability {
        let availability = admission?.expandedAvailability() ?? .available(topologyRevision: 0)
        snapshot.expandedAvailability = availability
        return availability
    }

    private func invalidateExpandedAvailability() {
        snapshot.expandedAvailability = .unknown
        clearAdmissionFeedback()
    }

    private func showAdmissionFeedback(for topologyRevision: UInt64) {
        clearAdmissionFeedback()
        snapshot.admissionFeedback = .expandedUnavailable(topologyRevision: topologyRevision)
        admissionFeedbackGeneration += 1
        let generation = admissionFeedbackGeneration
        admissionFeedbackTask = scheduler.schedule(after: SurfaceInteractionDefaults.admissionFeedbackDuration) {
            [weak self] in
            guard let self, self.admissionFeedbackGeneration == generation else { return }
            self.admissionFeedbackTask = nil
            self.snapshot.admissionFeedback = nil
            self.publishDebugSnapshot()
        }
    }

    private func clearAdmissionFeedback() {
        admissionFeedbackGeneration += 1
        admissionFeedbackTask?.cancel()
        admissionFeedbackTask = nil
        snapshot.admissionFeedback = nil
    }

    private func recordDiagnostic(_ event: SurfaceDiagnosticEvent) {
        diagnostics.record(event)
    }

    private func updateTimers(after intent: SurfaceIntent, state: SurfaceState) {
        if state == .hidden || state == .suppressed { isPointerInside = false }
        if state != .collapsed { cancelHoverExpansion() }
        if state == .expanded {
            if intent != .hoverDelayElapsed { scheduleAutoCollapse() }
        } else if state == .compact {
            scheduleAutoCollapse()
        } else {
            cancelAutoCollapse()
        }
        if intent == .hide || intent == .suppressed { cancelHoverExpansion() }
    }

    private func revalidateDisplayGeometry() {
        _ = handle(.displayInvalidated)
    }

    private func pauseInteraction() {
        guard snapshot.state != .hidden else { return }
        cancelHoverExpansion()
        cancelAutoCollapse()
        cancelRecovery()
        snapshot.isInteractionPaused = true
        _ = panel.apply(.pauseInteraction)
    }

    private func resumeAndRecover(restoring state: SurfaceState? = nil) {
        guard snapshot.state != .hidden else { return }
        snapshot.isInteractionPaused = false
        beginRecovery(restoring: state)
    }

    private func beginRecovery(restoring state: SurfaceState? = nil) {
        guard snapshot.state != .hidden, snapshot.state != .recovering else { return }
        cancelHoverExpansion()
        cancelAutoCollapse()
        invalidateInteractionSession()
        clearAdmissionFeedback()
        snapshot.state = .recovering
        snapshot.recoveryAttemptCount = 0
        snapshot.recoveryOutcome = .pending
        snapshot.warning = nil
        recoveryTargetState = state ?? .collapsed
        _ = panel.apply(.suppress)
        attemptRecovery()
    }

    private func attemptRecovery() {
        snapshot.recoveryAttemptCount += 1
        if geometryInput?.revalidateGeometry() == true {
            snapshot.recoveryOutcome = .recovered
            if snapshot.suppressionReason == .fullScreen || recoveryTargetState == .suppressed {
                snapshot.state = .suppressed
                return
            }
            let effect: SurfacePanelEffect =
                recoveryTargetState == .expanded
                ? .showExpanded(focus: false)
                : recoveryTargetState == .compact ? .showCompact : .showCollapsed
            guard panel.apply(effect) else { return failRecovery() }
            snapshot.state = recoveryTargetState
            if recoveryTargetState == .expanded {
                interactionSessionGeneration &+= 1
                expandedOrigin = .deliberate
            }
            return
        }
        guard snapshot.recoveryAttemptCount < 2 else {
            failRecovery()
            return
        }
        recoveryGeneration += 1
        let generation = recoveryGeneration
        recoveryTask = scheduler.schedule(after: SurfaceInteractionDefaults.recoveryBackoff) { [weak self] in
            guard let self, self.recoveryGeneration == generation else { return }
            self.recoveryTask = nil
            self.attemptRecovery()
            self.publishDebugSnapshot()
        }
    }

    private var recoveryTargetState: SurfaceState = .collapsed

    private func failRecovery() {
        snapshot.state = .hidden
        snapshot.recoveryOutcome = .failed
        snapshot.warning = .recoveryFailed
        _ = panel.apply(.hide)
    }

    private func cancelRecovery() {
        recoveryGeneration += 1
        recoveryTask?.cancel()
        recoveryTask = nil
    }

    private func publishDebugSnapshot() {
        (panel as? any SurfaceDebugOverlayPresenting)?.setDebugSnapshot(snapshot)
    }

    private func scheduleHoverExpansion() {
        cancelHoverExpansion()
        hoverGeneration += 1
        let generation = hoverGeneration
        hoverTask = scheduler.schedule(after: configuration.hoverDelay) { [weak self] in
            guard let self, self.hoverGeneration == generation else { return }
            self.hoverTask = nil
            _ = self.handle(.hoverDelayElapsed)
        }
    }

    private func cancelHoverExpansion() {
        hoverGeneration += 1
        hoverTask?.cancel()
        hoverTask = nil
    }

    private func scheduleAutoCollapse() {
        cancelAutoCollapse()
        collapseGeneration += 1
        let generation = collapseGeneration
        collapseTask = scheduler.schedule(after: configuration.autoCollapseDelay) { [weak self] in
            guard let self, self.collapseGeneration == generation else { return }
            self.collapseTask = nil
            _ = self.handle(.autoCollapseElapsed)
        }
    }

    private func cancelAutoCollapse() {
        collapseGeneration += 1
        collapseTask?.cancel()
        collapseTask = nil
    }

    private func scheduleCloseForCurrentOrigin() {
        guard interactionHolds.isEmpty, !isPointerInside else { return }
        if expandedOrigin == .hover {
            cancelAutoCollapse()
            collapseGeneration += 1
            let generation = collapseGeneration
            collapseTask = scheduler.schedule(after: SurfaceInteractionDefaults.hoverCloseGrace) { [weak self] in
                guard let self, self.collapseGeneration == generation else { return }
                self.collapseTask = nil
                _ = self.handle(.autoCollapseElapsed)
            }
        } else {
            scheduleAutoCollapse()
        }
    }

    private func scheduleOutsideClickCollapse() {
        cancelAutoCollapse()
        collapseGeneration += 1
        let generation = collapseGeneration
        collapseTask = scheduler.schedule(after: .zero) { [weak self] in
            guard let self, self.collapseGeneration == generation else { return }
            self.collapseTask = nil
            guard let state = self.apply(.clickedOutside) else { return }
            self.updateTimers(after: .clickedOutside, state: state)
            self.publishDebugSnapshot()
        }
    }

    private func invalidateInteractionSession() {
        interactionSessionGeneration &+= 1
        interactionHolds.removeAll()
        accessibilityInteractionHold = nil
        expandedOrigin = nil
        isPointerInside = false
        cancelAutoCollapse()
    }
}

public enum SurfaceInteractionHoldKind: CaseIterable, Equatable, Sendable {
    case keyboardFocus, popover, drag, confirmation, accessibilityInteraction
}

@MainActor
public final class SurfaceInteractionHoldLease {
    private weak var coordinator: SurfaceCoordinator?
    private let id: UUID
    private let generation: UInt64
    private var isReleased = false

    fileprivate init(coordinator: SurfaceCoordinator, id: UUID, generation: UInt64) {
        self.coordinator = coordinator
        self.id = id
        self.generation = generation
    }

    public func release() {
        guard !isReleased else { return }
        isReleased = true
        coordinator?.releaseInteractionHold(id: id, generation: generation)
    }
}

private enum SurfaceExpansionOrigin: Equatable {
    case hover, deliberate
}

public struct SurfaceSnapshot: Equatable, Sendable {
    public fileprivate(set) var state: SurfaceState = .hidden
    public fileprivate(set) var suppressionReason: SurfaceSuppressionReason?
    public fileprivate(set) var recoveryAttemptCount = 0
    public fileprivate(set) var recoveryOutcome: SurfaceRecoveryOutcome?
    public fileprivate(set) var warning: SurfaceWarning?
    public fileprivate(set) var isInteractionPaused = false
    public fileprivate(set) var expandedAvailability: SurfaceExpandedAvailability = .unknown
    public fileprivate(set) var admissionFeedback: SurfaceAdmissionFeedback?
    public init() {}
}

public enum SurfaceExpandedAvailability: Equatable, Sendable {
    case unknown
    case available(topologyRevision: UInt64)
    case unsupportedCapacity(topologyRevision: UInt64)
    case invalidTopology(topologyRevision: UInt64)
}

public enum SurfaceExpansionContract {
    public static let surfaceSize = CGSize(width: 640, height: 190)
    public static let hostSize = CGSize(width: 640, height: 210)
}

public enum SurfaceAdmissionFeedback: Equatable, Sendable {
    case expandedUnavailable(topologyRevision: UInt64)
}

public enum SurfaceDiagnosticEvent: Equatable, Sendable {
    case unsupportedExpandedCapacity(topologyRevision: UInt64)
    case invalidExpandedTopology(topologyRevision: UInt64)
    case nativeExpandedPanelFailure
}

public struct SurfaceDiagnostics: Equatable, Sendable {
    public private(set) var events: [SurfaceDiagnosticEvent] = []
    private static let maximumEvents = 20

    public init() {}

    fileprivate mutating func record(_ event: SurfaceDiagnosticEvent) {
        events.append(event)
        if events.count > Self.maximumEvents {
            events.removeFirst(events.count - Self.maximumEvents)
        }
    }
}

public enum SurfaceSuppressionReason: Equatable, Sendable { case fullScreen }
public enum SurfaceRecoveryOutcome: Equatable, Sendable { case pending, recovered, failed }
public enum SurfaceWarning: Equatable, Sendable { case recoveryFailed }

public enum SurfaceIntent: Equatable, Sendable {
    case toggle, showCollapsed, hide, hoverEntered, hoverExited, hoverDelayElapsed
    case clicked, keyboardRequestedExpansion, interaction
    case escapePressed, clickedOutside, autoCollapseElapsed, suppressed, showCompact
    case fullScreenPolicyEngaged, fullScreenPolicyCleared
    case willSleep, didWake, sessionLocked, sessionUnlocked, displayInvalidated
    case accessibilityInteractionBegan, accessibilityInteractionEnded
}

public enum SurfacePanelEffect: Equatable, Sendable {
    case showCollapsed
    case showCompact
    case showExpanded(focus: Bool)
    case hide
    case suppress
    case pauseInteraction
}

@MainActor
public protocol SurfacePanelPresenting: AnyObject {
    func apply(_ effect: SurfacePanelEffect) -> Bool
}

@MainActor
public protocol SurfaceFocusRestoring: AnyObject {
    func restoreFocusAfterSurfaceInteraction()
}

@MainActor
public protocol SurfaceExpansionAdmitting: AnyObject {
    func expandedAvailability() -> SurfaceExpandedAvailability
}

@MainActor
public protocol SurfaceDebugOverlayPresenting: AnyObject {
    func setDebugSnapshot(_ snapshot: SurfaceSnapshot)
}

@MainActor
public protocol SurfaceDebugOverlayToggling: SurfaceDebugOverlayPresenting {
    func toggleDebugOverlay() -> Bool
}

@MainActor
public protocol SurfaceInputMonitoring: AnyObject {
    func setInteractionHandler(_ handler: @escaping @MainActor (SurfaceIntent) -> Void)
}

@MainActor
public protocol SurfaceDisplayObserving: AnyObject {
    func setDisplayChangeHandler(_ handler: @escaping @MainActor () -> Void)
}

@MainActor
public protocol SurfaceGeometryRevalidating: SurfaceDisplayObserving {
    func revalidateGeometry() -> Bool
}

@MainActor
public protocol SurfaceContextObserving: AnyObject {
    func setContextChangeHandler(_ handler: @escaping @MainActor (SurfaceIntent) -> Void)
}

@MainActor
public protocol SurfaceInteractionScheduling: AnyObject {
    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> any SurfaceInteractionTask
}

@MainActor
public protocol SurfaceInteractionTask: AnyObject { func cancel() }

@MainActor
private final class MainQueueSurfaceScheduler: SurfaceInteractionScheduling {
    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> any SurfaceInteractionTask {
        let task = MainQueueSurfaceTask()
        task.start(after: delay, action)
        return task
    }
}

@MainActor
private final class MainQueueSurfaceTask: SurfaceInteractionTask {
    private var task: Task<Void, Never>?

    func start(after delay: Duration, _ action: @escaping @MainActor () -> Void) {
        task = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel() { task?.cancel() }
}

public enum SurfaceStateMachine {
    public static func transition(
        from state: SurfaceState,
        for intent: SurfaceIntent
    ) -> (state: SurfaceState, effect: SurfacePanelEffect)? {
        switch (state, intent) {
        case (.hidden, .toggle), (.hidden, .showCollapsed):
            (.collapsed, .showCollapsed)
        case (.collapsed, .toggle), (.collapsed, .hide):
            (.hidden, .hide)
        case (.collapsed, .hoverDelayElapsed):
            (.expanded, .showExpanded(focus: false))
        case (.collapsed, .keyboardRequestedExpansion):
            (.expanded, .showExpanded(focus: true))
        case (.collapsed, .showCompact):
            (.compact, .showCompact)
        case (.compact, .clicked):
            (.expanded, .showExpanded(focus: true))
        case (.compact, .keyboardRequestedExpansion):
            (.expanded, .showExpanded(focus: true))
        case (.compact, .autoCollapseElapsed),
            (.expanded, .escapePressed), (.expanded, .clickedOutside), (.expanded, .autoCollapseElapsed):
            (.collapsed, .showCollapsed)
        case (.suppressed, .showCollapsed):
            (.collapsed, .showCollapsed)
        case (_, .suppressed):
            (.suppressed, .suppress)
        default:
            nil
        }
    }
}
