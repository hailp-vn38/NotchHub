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

private struct DemoModule: NotchModule {
    let id: ModuleID
    let metadata = ModuleMetadata(displayName: "Demo")
}
