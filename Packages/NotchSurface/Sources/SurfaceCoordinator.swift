import NotchCore
import NotchDomain

@MainActor
public final class SurfaceCoordinator: NotchSurfaceToggling {
    public private(set) var snapshot = SurfaceSnapshot()
    private let panel: any SurfacePanelPresenting

    public init(panel: any SurfacePanelPresenting) {
        self.panel = panel
    }

    @discardableResult
    public func handle(_ intent: SurfaceIntent) -> SurfaceState {
        _ = apply(intent)
        return snapshot.state
    }

    public func toggleNotchSurface() -> NotchSurfaceToggleResult {
        guard let state = apply(.toggle) else { return .unavailable }

        return switch state {
        case .collapsed:
            .shownCollapsed
        case .hidden:
            .hidden
        default:
            .unavailable
        }
    }

    private func apply(_ intent: SurfaceIntent) -> SurfaceState? {
        guard let transition = SurfaceStateMachine.transition(from: snapshot.state, for: intent),
            panel.apply(transition.effect)
        else {
            return nil
        }

        snapshot.state = transition.state
        return snapshot.state
    }
}

public struct SurfaceSnapshot: Equatable, Sendable {
    public fileprivate(set) var state: SurfaceState = .hidden

    public init() {}
}

public enum SurfaceIntent: Sendable {
    case toggle
    case showCollapsed
    case hide
}

public enum SurfacePanelEffect: Equatable, Sendable {
    case showCollapsed
    case hide
}

@MainActor
public protocol SurfacePanelPresenting: AnyObject {
    func apply(_ effect: SurfacePanelEffect) -> Bool
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
        default:
            nil
        }
    }
}
