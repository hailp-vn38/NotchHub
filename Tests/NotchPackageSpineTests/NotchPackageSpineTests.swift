import Foundation
import NotchCore
import NotchDomain
import Testing

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

private struct DemoModule: NotchModule {
    let id: ModuleID
    let metadata = ModuleMetadata(displayName: "Demo")
}
