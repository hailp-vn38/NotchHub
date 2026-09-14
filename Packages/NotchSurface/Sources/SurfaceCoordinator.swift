import NotchCore
import NotchDomain

public enum SurfaceInteractionDefaults {
    public static let hoverDelay: Duration = .milliseconds(150)
    public static let autoCollapseDelay: Duration = .seconds(3)
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
public final class SurfaceCoordinator: NotchSurfaceToggling, NotchSurfaceLifecycleHandling,
    NotchSurfaceDebugToggling
{
    public private(set) var snapshot = SurfaceSnapshot()
    private let panel: any SurfacePanelPresenting
    private let input: (any SurfaceInputMonitoring)?
    private let geometryInput: (any SurfaceGeometryRevalidating)?
    private let contextInput: (any SurfaceContextObserving)?
    private let detailInput: (any DetailNavigationInput)?
    private let detailNavigator: (any DetailNavigating)?
    private let scheduler: any SurfaceInteractionScheduling
    private let configuration: SurfaceInteractionConfiguration
    private var hoverTask: (any SurfaceInteractionTask)?
    private var collapseTask: (any SurfaceInteractionTask)?
    private var hoverGeneration = 0
    private var collapseGeneration = 0
    private var isHoveringExpanded = false
    private var recoveryTask: (any SurfaceInteractionTask)?
    private var recoveryGeneration = 0
    private var sessionResumeState: SurfaceState?

    public init(
        panel: any SurfacePanelPresenting,
        scheduler: (any SurfaceInteractionScheduling)? = nil,
        configuration: SurfaceInteractionConfiguration = .init(),
        input: (any SurfaceInputMonitoring)? = nil,
        detailNavigator: (any DetailNavigating)? = nil
    ) {
        self.panel = panel
        self.input = input ?? (panel as? any SurfaceInputMonitoring)
        self.geometryInput = panel as? any SurfaceGeometryRevalidating
        self.contextInput = panel as? any SurfaceContextObserving
        self.detailInput = self.input as? any DetailNavigationInput
        self.detailNavigator = detailNavigator
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
        self.detailInput?.setDetailNavigationHandler { [weak detailNavigator] request in
            _ = detailNavigator?.open(request)
        }
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
        case .didWake, .displayInvalidated:
            resumeAndRecover()
        case .sessionUnlocked:
            resumeAndRecover(restoring: sessionResumeState)
            sessionResumeState = nil
        case .hoverEntered where snapshot.state == .collapsed:
            scheduleHoverExpansion()
        case .hoverExited:
            cancelHoverExpansion()
        case .expandedHoverEntered where snapshot.state == .expanded:
            isHoveringExpanded = true
            cancelAutoCollapse()
        case .expandedHoverExited where snapshot.state == .expanded:
            isHoveringExpanded = false
            scheduleAutoCollapse()
        case .interaction where snapshot.state == .expanded:
            if !isHoveringExpanded { scheduleAutoCollapse() }
        default:
            guard let state = apply(intent) else { return snapshot.state }
            updateTimers(after: intent, state: state)
        }
        return snapshot.state
    }

    public func toggleNotchSurface() -> NotchSurfaceToggleResult {
        let priorState = snapshot.state
        let state = handle(.toggle)
        guard state != priorState else { return .unavailable }
        return switch state {
        case .collapsed: .shownCollapsed
        case .hidden: .hidden
        default: .unavailable
        }
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
        guard let transition = SurfaceStateMachine.transition(from: snapshot.state, for: intent),
            panel.apply(transition.effect)
        else { return nil }
        snapshot.state = transition.state
        return snapshot.state
    }

    private func updateTimers(after intent: SurfaceIntent, state: SurfaceState) {
        if state != .collapsed { cancelHoverExpansion() }
        if state == .expanded || state == .compact { scheduleAutoCollapse() } else { cancelAutoCollapse() }
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
}

public struct SurfaceSnapshot: Equatable, Sendable {
    public fileprivate(set) var state: SurfaceState = .hidden
    public fileprivate(set) var suppressionReason: SurfaceSuppressionReason?
    public fileprivate(set) var recoveryAttemptCount = 0
    public fileprivate(set) var recoveryOutcome: SurfaceRecoveryOutcome?
    public fileprivate(set) var warning: SurfaceWarning?
    public fileprivate(set) var isInteractionPaused = false
    public init() {}
}

public enum SurfaceSuppressionReason: Equatable, Sendable { case fullScreen }
public enum SurfaceRecoveryOutcome: Equatable, Sendable { case pending, recovered, failed }
public enum SurfaceWarning: Equatable, Sendable { case recoveryFailed }

public enum SurfaceIntent: Equatable, Sendable {
    case toggle, showCollapsed, hide, hoverEntered, hoverExited, hoverDelayElapsed
    case expandedHoverEntered, expandedHoverExited, clicked, interaction
    case escapePressed, clickedOutside, autoCollapseElapsed, suppressed, showCompact
    case fullScreenPolicyEngaged, fullScreenPolicyCleared
    case willSleep, didWake, sessionLocked, sessionUnlocked, displayInvalidated
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
        case (.collapsed, .clicked):
            (.expanded, .showExpanded(focus: true))
        case (.collapsed, .showCompact):
            (.compact, .showCompact)
        case (.compact, .clicked):
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
