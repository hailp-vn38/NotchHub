/// The F1 owner of in-process App shell coordination.
@MainActor
public final class AppCoordinator {
    public private(set) var snapshot = AppShellSnapshot()

    public init() {}

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
    case restartAppShell
    case quit
}

public enum AppShellMenuOutcome: Equatable, Sendable {
    case unavailable(AppShellUnavailableFeature)
    case restarted
    case quitRequested

    public var message: String {
        switch self {
        case .unavailable(let feature):
            "\(feature.title) is unavailable until its owning phase is implemented."
        case .restarted:
            "App shell restarted."
        case .quitRequested:
            "Quitting NotchHub."
        }
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
