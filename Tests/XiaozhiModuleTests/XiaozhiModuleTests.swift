import Foundation
import NotchCore
import NotchDomain
import Testing
import XiaozhiModule

@Test("Xiaozhi identity validates generated stable IDs")
func xiaozhiIdentity() {
    #expect(XiaozhiIdentity.isValidDeviceID(XiaozhiIdentity.randomDeviceID()))
    #expect(XiaozhiIdentity.isValidClientID(UUID().uuidString.lowercased()))
    #expect(!XiaozhiIdentity.isValidDeviceID("00:11:22:33:44:55"))
    #expect(!XiaozhiIdentity.isValidDeviceID("03:11:22:33:44:55"))
}

@Test("Xiaozhi settings persist only non-secret prepared, reconnect, and conversation preferences")
func xiaozhiSettings() async throws {
    let store = SettingsStore(backend: XiaozhiMemorySettingsBackend())
    let settings = XiaozhiSettings(isPreparedOnLaunch: false, autoReconnect: false, conversationMode: .pushToTalk)
    #expect((await store.mutate(.xiaozhi(settings))).outcome == .saved)
    let exported = try await store.exportSanitized()
    #expect(exported.contains(Data("deviceID".utf8)) == false)
}

@Test("Enabling Xiaozhi reaches ready without opening a voice connection or microphone capture")
func xiaozhiReadinessIsPassive() async throws {
    let module = XiaozhiModule()
    let runtime = ModuleRuntime()

    await runtime.register(module, enabled: true)
    await runtime.start(module.id)

    let health = try #require(await runtime.health(for: module.id))
    #expect(health.state == .running)
    #expect(await runtime.contributions(for: module.id).map(\.text) == ["Xiaozhi", "Xiaozhi ready"])
    #expect(await runtime.activeResourceCount(for: module.id) == 3)
}

@Test("Xiaozhi secrets use a credential boundary and diagnostics redact token-like values")
func xiaozhiCredentialsAndDiagnosticsArePrivate() throws {
    let credentials = XiaozhiMemoryCredentialStore()
    try credentials.saveCredential("bootstrap-token")
    #expect(try credentials.credential() == "bootstrap-token")

    let diagnostic = XiaozhiDiagnostics.redact([
        "token": "bootstrap-token",
        "nested": ["authorization": "Bearer bootstrap-token"],
        "state": "ready",
    ]) as? [String: Any]
    #expect(diagnostic?["token"] as? String == "[REDACTED]")
    #expect((diagnostic?["nested"] as? [String: String])?["authorization"] == "[REDACTED]")
    #expect(diagnostic?["state"] as? String == "ready")
}

@Test("Xiaozhi bootstrap accepts activation-only and ready fake-cloud responses without persisting tokens")
func decodesXiaozhiBootstrapResponses() throws {
    let activation = Data("""
    {"activation":{"message":"Activate this Mac","code":"123456","challenge":"challenge"}}
    """.utf8)
    let ready = Data("""
    {"websocket":{"url":"wss://example.test/voice","token":"temporary-token","version":1}}
    """.utf8)

    let activationResponse = try JSONDecoder().decode(XiaozhiBootstrapResponse.self, from: activation)
    let readyResponse = try JSONDecoder().decode(XiaozhiBootstrapResponse.self, from: ready)

    #expect(activationResponse.activation?.code == "123456")
    #expect(activationResponse.websocket == nil)
    #expect(readyResponse.activation == nil)
    #expect(readyResponse.websocket?.url == URL(string: "wss://example.test/voice"))
    #expect(readyResponse.websocket?.token == "temporary-token")
}

@Test("The user-invoked Xiaozhi preparation bootstraps and saves only a ready-session credential")
func preparesXiaozhiOnUserAction() async throws {
    let credentials = XiaozhiMemoryCredentialStore()
    let events = RecordingModuleEventPublisher()
    let module = XiaozhiModule(
        bootstrap: XiaozhiFakeBootstrap(response: .init(
            activation: nil,
            websocket: .init(url: URL(string: "wss://example.test/voice")!, token: "temporary-token", version: 1)
        )),
        credentials: credentials,
        identity: XiaozhiFakeIdentity()
    )
    let runtime = ModuleRuntime(eventPublisher: events)
    await runtime.register(module, enabled: true)
    await runtime.start(module.id)

    await runtime.actions.invoke(try #require(ActionID("xiaozhi.prepare")))

    #expect(try credentials.credential() == "temporary-token")
    #expect(await events.events.contains(.init(moduleID: module.id, type: EventType("xiaozhi.ready")!)))
}

private actor XiaozhiMemorySettingsBackend: SettingsBackend {
    private var active: Data?

    func readActive() async throws -> Data? { active }
    func replaceActive(with data: Data) async throws { active = data }
    func quarantine(_: Data) async throws {}
}

private final class XiaozhiMemoryCredentialStore: XiaozhiCredentialStoring, @unchecked Sendable {
    private var value: String?
    func credential() throws -> String? { value }
    func saveCredential(_ value: String) throws { self.value = value }
    func removeCredential() throws { value = nil }
}

private struct XiaozhiFakeBootstrap: XiaozhiBootstrapping {
    let response: XiaozhiBootstrapResponse
    func bootstrap(_: XiaozhiBootstrapRequest) async throws -> XiaozhiBootstrapResponse { response }
}

private struct XiaozhiFakeIdentity: XiaozhiIdentityStoring {
    func deviceID() throws -> String { "02:11:22:33:44:55" }
    func clientID() throws -> String { "d1a6d617-337a-439a-ad02-5cf5c447a755" }
}
