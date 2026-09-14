import NotchDomain

/// The F1 owner of in-process App shell coordination.
@MainActor
public final class AppCoordinator {
    public private(set) var snapshot = AppShellSnapshot()
    private let scenePresenter: any AppShellScenePresenter
    private let lifecycleObserver: any AppShellLifecycleObserving
    private let launchAtLoginController: any LaunchAtLoginControlling
    private let surfaceController: any NotchSurfaceLifecycleControlling

    public init(
        scenePresenter: (any AppShellScenePresenter)? = nil,
        lifecycleObserver: (any AppShellLifecycleObserving)? = nil,
        launchAtLoginController: (any LaunchAtLoginControlling)? = nil,
        surfaceController: (any NotchSurfaceLifecycleControlling)? = nil
    ) {
        self.scenePresenter = scenePresenter ?? NoopScenePresenter()
        self.lifecycleObserver = lifecycleObserver ?? NoopLifecycleObserver()
        self.launchAtLoginController = launchAtLoginController ?? UnavailableLaunchAtLoginController()
        self.surfaceController = surfaceController ?? UnavailableNotchSurfaceController()
    }

    @discardableResult
    public func start() -> AppShellStartResult {
        guard !snapshot.isRunning else { return .alreadyRunning }
        snapshot.isRunning = true
        snapshot.startCount += 1
        snapshot.lifecycleState = .running
        surfaceController.start()
        snapshot.launchAtLoginStatus = launchAtLoginController.status()
        lifecycleObserver.start { [weak self] event in
            self?.handleLifecycleEvent(event)
        }
        return .started
    }

    @discardableResult
    public func perform(_ intent: AppShellMenuIntent) -> AppShellMenuOutcome {
        switch intent {
        case .openSettings:
            return presentPlaceholderScene(.settings)
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

    private func handleLifecycleEvent(_ event: AppShellLifecycleEvent) {
        surfaceController.handleAppShellLifecycle(event)
        switch event {
        case .activated, .didWake, .unlocked:
            guard snapshot.isRunning else { return }
            snapshot.lifecycleState = .running
        case .deactivated:
            guard snapshot.isRunning else { return }
            snapshot.lifecycleState = .inactive
        case .willSleep:
            guard snapshot.isRunning else { return }
            snapshot.lifecycleState = .sleeping
        case .locked:
            guard snapshot.isRunning else { return }
            snapshot.lifecycleState = .locked
        case .willTerminate:
            stop()
        }
    }

    private func stop() {
        guard snapshot.isRunning else { return }
        lifecycleObserver.stop()
        surfaceController.stop()
        snapshot.isRunning = false
        snapshot.lifecycleState = .stopped
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
    public fileprivate(set) var lifecycleState: AppShellLifecycleState = .stopped
    public fileprivate(set) var launchAtLoginStatus: LaunchAtLoginStatus = .unavailable

    public init() {}
}

public enum AppShellLifecycleState: Equatable, Sendable {
    case running
    case inactive
    case sleeping
    case locked
    case stopped
}

public enum AppShellLifecycleEvent: Sendable {
    case activated
    case deactivated
    case willSleep
    case didWake
    case locked
    case unlocked
    case willTerminate
}

@MainActor
public protocol AppShellLifecycleObserving: AnyObject {
    func start(observing handler: @escaping @MainActor (AppShellLifecycleEvent) -> Void)
    func stop()
}

public enum LaunchAtLoginStatus: CaseIterable, Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
    case unavailable
}

@MainActor
public protocol LaunchAtLoginControlling {
    func status() -> LaunchAtLoginStatus
}

public enum AppShellStartResult: Equatable, Sendable {
    case started
    case alreadyRunning
}

public enum AppShellMenuIntent: Sendable {
    case openSettings
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

@MainActor
private final class NoopLifecycleObserver: AppShellLifecycleObserving {
    func start(observing _: @escaping @MainActor (AppShellLifecycleEvent) -> Void) {}
    func stop() {}
}

@MainActor
private final class UnavailableLaunchAtLoginController: LaunchAtLoginControlling {
    func status() -> LaunchAtLoginStatus { .unavailable }
}

@MainActor
public protocol NotchSurfaceLifecycleControlling: AnyObject {
    func start()
    func stop()
    func handleAppShellLifecycle(_ event: AppShellLifecycleEvent)
}

@MainActor
public protocol NotchSurfaceDebugToggling: AnyObject {
    func toggleDebugOverlay() -> Bool
}

@MainActor
private final class UnavailableNotchSurfaceController: NotchSurfaceLifecycleControlling {
    func start() {}
    func stop() {}
    func handleAppShellLifecycle(_: AppShellLifecycleEvent) {}
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
