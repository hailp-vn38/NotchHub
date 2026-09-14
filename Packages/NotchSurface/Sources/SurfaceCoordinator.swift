import NotchCore
import NotchDomain

public enum SurfaceInteractionDefaults {
    public static let hoverDelay: Duration = .milliseconds(150)
    public static let autoCollapseDelay: Duration = .seconds(3)
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
public final class SurfaceCoordinator: NotchSurfaceToggling {
    public private(set) var snapshot = SurfaceSnapshot()
    private let panel: any SurfacePanelPresenting
    private let input: (any SurfaceInputMonitoring)?
    private let geometryInput: (any SurfaceGeometryRevalidating)?
    private let detailInput: (any DetailNavigationInput)?
    private let detailNavigator: (any DetailNavigating)?
    private let scheduler: any SurfaceInteractionScheduling
    private let configuration: SurfaceInteractionConfiguration
    private var hoverTask: (any SurfaceInteractionTask)?
    private var collapseTask: (any SurfaceInteractionTask)?
    private var hoverGeneration = 0
    private var collapseGeneration = 0
    private var isHoveringExpanded = false

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
        self.detailInput?.setDetailNavigationHandler { [weak detailNavigator] request in
            _ = detailNavigator?.open(request)
        }
    }

    @discardableResult
    public func handle(_ intent: SurfaceIntent) -> SurfaceState {
        switch intent {
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
        guard snapshot.state != .hidden else { return }
        guard geometryInput?.revalidateGeometry() == true else {
            _ = handle(.suppressed)
            return
        }
        if snapshot.state == .suppressed {
            _ = handle(.showCollapsed)
        }
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
    public init() {}
}

public enum SurfaceIntent: Equatable, Sendable {
    case toggle, showCollapsed, hide, hoverEntered, hoverExited, hoverDelayElapsed
    case expandedHoverEntered, expandedHoverExited, clicked, interaction
    case escapePressed, clickedOutside, autoCollapseElapsed, suppressed, showCompact
}

public enum SurfacePanelEffect: Equatable, Sendable {
    case showCollapsed
    case showCompact
    case showExpanded(focus: Bool)
    case hide
    case suppress
}

@MainActor
public protocol SurfacePanelPresenting: AnyObject {
    func apply(_ effect: SurfacePanelEffect) -> Bool
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
