/// The F1 owner of in-process App shell coordination.
@MainActor
public final class AppCoordinator {
    public private(set) var snapshot = AppShellSnapshot()
    private let scenePresenter: any AppShellScenePresenter

    public init(scenePresenter: (any AppShellScenePresenter)? = nil) {
        self.scenePresenter = scenePresenter ?? NoopScenePresenter()
    }

    @discardableResult
    public func start() -> AppShellStartResult {
        guard !snapshot.isRunning else { return .alreadyRunning }
        snapshot.isRunning = true
        snapshot.startCount += 1
        return .started
    }

    @discardableResult
    public func perform(_ intent: AppShellMenuIntent) -> AppShellMenuOutcome {
        switch intent {
        case .toggleNotchSurface:
            return .unavailable(.notchSurface)
        case .showDemoState:
            return .unavailable(.demoState)
        case .openSettings:
            return presentPlaceholderScene(.settings)
        case .openDiagnostics:
            return presentPlaceholderScene(.diagnostics)
        case .restartAppShell:
            stop()
            _ = start()
            return .restarted
        case .quit:
            stop()
            return .quitRequested
        }
    }

    public func shutdown() {
        stop()
    }

    private func stop() {
        snapshot.isRunning = false
    }

    private func presentPlaceholderScene(_ scene: AppShellPlaceholderScene) -> AppShellMenuOutcome {
        scenePresenter.present(scene) == .presented
            ? .placeholderSceneRequested(scene)
            : .placeholderSceneUnavailable(scene)
    }
}

public struct AppShellSnapshot: Equatable, Sendable {
    public fileprivate(set) var isRunning = false
    public fileprivate(set) var startCount = 0

    public init() {}
}

public enum AppShellStartResult: Equatable, Sendable {
    case started
    case alreadyRunning
}

public enum AppShellMenuIntent: Sendable {
    case toggleNotchSurface
    case showDemoState
    case openSettings
    case openDiagnostics
    case restartAppShell
    case quit
}

public enum AppShellMenuOutcome: Equatable, Sendable {
    case unavailable(AppShellUnavailableFeature)
    case placeholderSceneRequested(AppShellPlaceholderScene)
    case placeholderSceneUnavailable(AppShellPlaceholderScene)
    case restarted
    case quitRequested

    public var message: String {
        switch self {
        case .unavailable(let feature):
            "\(feature.title) is unavailable until its owning phase is implemented."
        case .placeholderSceneRequested(let scene):
            "Opening \(scene.title) placeholder."
        case .placeholderSceneUnavailable(let scene):
            "\(scene.title) placeholder is unavailable."
        case .restarted:
            "App shell restarted."
        case .quitRequested:
            "Quitting NotchHub."
        }
    }
}

public enum AppShellPlaceholderScene: Equatable, Hashable, Sendable {
    case settings
    case diagnostics

    public var title: String {
        switch self {
        case .settings:
            "Settings"
        case .diagnostics:
            "Diagnostics"
        }
    }

    public var windowID: String {
        switch self {
        case .settings:
            "settings-placeholder"
        case .diagnostics:
            "diagnostics-placeholder"
        }
    }
}

@MainActor
public protocol AppShellScenePresenter: AnyObject {
    func present(_ scene: AppShellPlaceholderScene) -> AppShellScenePresentationResult
}

public enum AppShellScenePresentationResult: Equatable, Sendable {
    case presented
    case unavailable
}

@MainActor
private final class NoopScenePresenter: AppShellScenePresenter {
    func present(_: AppShellPlaceholderScene) -> AppShellScenePresentationResult {
        .unavailable
    }
}

public enum AppShellUnavailableFeature: Equatable, Sendable {
    case notchSurface
    case demoState

    fileprivate var title: String {
        switch self {
        case .notchSurface:
            "Notch surface"
        case .demoState:
            "Demo state"
        }
    }
}
