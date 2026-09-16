import Foundation
import NotchCore
import NotchDomain
import Testing
@testable import XiaozhiModule

@Test("Xiaozhi identity validates generated stable IDs")
func xiaozhiIdentity() {
    #expect(XiaozhiIdentity.isValidDeviceID(XiaozhiIdentity.randomDeviceID()))
    #expect(XiaozhiIdentity.isValidClientID(UUID().uuidString.lowercased()))
    #expect(!XiaozhiIdentity.isValidDeviceID("00:11:22:33:44:55"))
    #expect(!XiaozhiIdentity.isValidDeviceID("03:11:22:33:44:55"))
}

@Test("Production Opus codec creates the encoder required by a Settings connection test")
func createsProductionOpusEncoder() throws {
    _ = try XiaozhiOpusCodec()
}

@Test("Xiaozhi settings persist non-secret configuration and editable identity")
func xiaozhiSettings() async throws {
    let store = SettingsStore(backend: XiaozhiMemorySettingsBackend())
    let settings = XiaozhiSettings(
        isPreparedOnLaunch: false, autoReconnect: false, conversationMode: .pushToTalk, ttsMuted: true)
    #expect((await store.mutate(.xiaozhi(settings))).outcome == .saved)
    let exported = try await store.exportSanitized()
    #expect(exported.contains(Data("deviceID".utf8)))
    #expect((await store.load()).settings.xiaozhi.ttsMuted)
}

@Test("Enabling Xiaozhi reaches ready without opening a voice connection or microphone capture")
func xiaozhiReadinessIsPassive() async throws {
    let module = XiaozhiModule()
    let runtime = ModuleRuntime()

    await runtime.register(module, enabled: true)
    await runtime.start(module.id)

    let health = try #require(await runtime.health(for: module.id))
    #expect(health.state == .running)
    #expect(await runtime.contributions(for: module.id).map(\.text) == ["Xiaozhi", "Xiaozhi Ready", "Ready"])
}

@Test("Xiaozhi session credentials are never persisted and diagnostics redact token-like values")
func xiaozhiCredentialsAndDiagnosticsArePrivate() throws {
    let diagnostic =
        XiaozhiDiagnostics.redact([
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
    let activation = Data(
        """
        {"activation":{"message":"Activate this Mac","code":"123456","challenge":"challenge"}}
        """.utf8)
    let ready = Data(
        """
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

@Test("Xiaozhi Cloud websocket defaults the omitted protocol version to V1")
func defaultsCloudWebSocketVersion() throws {
    let response = try JSONDecoder().decode(
        XiaozhiBootstrapResponse.self,
        from: Data("{\"websocket\":{\"url\":\"wss://example.test/voice\",\"token\":\"temporary-token\"}}".utf8))
    #expect(response.websocket?.version == 1)
}

@Test("Connection test returns the first-link six-digit activation PIN without persisting it")
func exposesFirstLinkActivationPIN() async throws {
    let tester = XiaozhiConnectionTester(
        bootstrapFactory: { _ in
            XiaozhiFakeBootstrap(response: .init(activation: .init(code: "123456")))
        })
    do {
        _ = try await tester.testConnection(settings: .init()) { _ in }
        Issue.record("Expected an activation PIN")
    } catch let activation as XiaozhiActivationRequired {
        #expect(activation.code == "123456")
    }
}

@Test("Connection test prioritizes activation over a bootstrap test WebSocket")
func prioritizesActivationOverBootstrapWebSocket() async throws {
    let tester = XiaozhiConnectionTester(
        bootstrapFactory: { _ in
            XiaozhiFakeBootstrap(response: .init(
                activation: .init(code: "123456"),
                websocket: .init(url: URL(string: "wss://example.test/voice")!, token: "test-token", version: 1)))
        },
        voiceFactory: { throw XiaozhiTestVoiceFactoryError() })
    do {
        _ = try await tester.testConnection(settings: .init()) { _ in }
        Issue.record("Expected an activation PIN")
    } catch let activation as XiaozhiActivationRequired {
        #expect(activation.code == "123456")
    }
}

@Test("Connection test returns sanitized bootstrap failure details at its first step")
func reportsBootstrapFailureDetail() async throws {
    let tester = XiaozhiConnectionTester(bootstrapFactory: { _ in XiaozhiFailingBootstrap() })
    do {
        _ = try await tester.testConnection(settings: .init()) { _ in }
        Issue.record("Expected a bootstrap failure")
    } catch let failure as XiaozhiConnectionTestFailure {
        #expect(failure.detail.hasPrefix("Bootstrap request failed:"))
    }
}

@Test("Connection test reports a sanitized HTTP rejection status")
func reportsBootstrapHTTPStatus() async throws {
    let tester = XiaozhiConnectionTester(bootstrapFactory: { _ in XiaozhiHTTPFailingBootstrap() })
    do {
        _ = try await tester.testConnection(settings: .init()) { _ in }
        Issue.record("Expected a bootstrap rejection")
    } catch let failure as XiaozhiConnectionTestFailure {
        #expect(failure.detail == "Bootstrap rejected the request (HTTP 400).")
    }
}

@Test("Connection test turns a WebSocket opening failure into a sanitized detail")
func reportsWebSocketOpeningFailureDetail() async throws {
    let tester = XiaozhiConnectionTester(
        bootstrapFactory: { _ in
            XiaozhiFakeBootstrap(response: .init(websocket: .init(
                url: URL(string: "wss://example.test/voice")!, token: "temporary-token", version: 1)))
        },
        voiceFactory: {
            XiaozhiVoiceSession(
                connector: XiaozhiFailingVoiceConnector(), capture: XiaozhiFakeAudioCapture(),
                playback: XiaozhiFakeAudioPlayback(), codec: XiaozhiFakeOpusCodec())
        })
    do {
        _ = try await tester.testConnection(settings: .init()) { _ in }
        Issue.record("Expected a WebSocket connection failure")
    } catch let failure as XiaozhiConnectionTestFailure {
        #expect(failure.detail == "WebSocket connection was closed before Xiaozhi could receive hello.")
    }
}

@Test("Connection test classifies an NSURLSession NSError from the WebSocket delegate")
func reportsBridgedWebSocketOpeningFailureDetail() async throws {
    let tester = XiaozhiConnectionTester(
        bootstrapFactory: { _ in
            XiaozhiFakeBootstrap(response: .init(websocket: .init(
                url: URL(string: "wss://example.test/voice")!, token: "temporary-token", version: 1)))
        },
        voiceFactory: {
            XiaozhiVoiceSession(
                connector: XiaozhiBridgedFailingVoiceConnector(), capture: XiaozhiFakeAudioCapture(),
                playback: XiaozhiFakeAudioPlayback(), codec: XiaozhiFakeOpusCodec())
        })
    do {
        _ = try await tester.testConnection(settings: .init()) { _ in }
        Issue.record("Expected a WebSocket connection failure")
    } catch let failure as XiaozhiConnectionTestFailure {
        #expect(failure.detail == "WebSocket connection was closed before Xiaozhi could receive hello.")
    }
}

@Test("Connection test reports a server close before Server Hello")
func reportsServerCloseBeforeServerHello() async throws {
    let tester = XiaozhiConnectionTester(
        bootstrapFactory: { _ in
            XiaozhiFakeBootstrap(response: .init(websocket: .init(
                url: URL(string: "wss://example.test/voice")!, token: "temporary-token", version: 1)))
        },
        voiceFactory: {
            XiaozhiVoiceSession(
                connector: XiaozhiDisconnectingVoiceConnector(), capture: XiaozhiFakeAudioCapture(),
                playback: XiaozhiFakeAudioPlayback(), codec: XiaozhiFakeOpusCodec())
        })
    do {
        _ = try await tester.testConnection(settings: .init()) { _ in }
        Issue.record("Expected a Server Hello failure")
    } catch let failure as XiaozhiConnectionTestFailure {
        #expect(failure.detail == "Xiaozhi server closed the WebSocket before sending Server Hello.")
    }
}

@Test("The user-invoked Xiaozhi preparation bootstraps without persisting a credential")
func preparesXiaozhiOnUserAction() async throws {
    let events = RecordingModuleEventPublisher()
    let module = XiaozhiModule(
        bootstrap: XiaozhiFakeBootstrap(
            response: .init(
                activation: nil,
                websocket: .init(url: URL(string: "wss://example.test/voice")!, token: "temporary-token", version: 1)
            )),
        settingsProvider: { XiaozhiSettings(deviceID: "02:11:22:33:44:55", clientID: "d1a6d617-337a-439a-ad02-5cf5c447a755") }
    )
    let runtime = ModuleRuntime(eventPublisher: events)
    await runtime.register(module, enabled: true)
    await runtime.start(module.id)

    await runtime.actions.invoke(try #require(ActionID("xiaozhi.prepare")))

    #expect(await events.events.contains(.init(moduleID: module.id, type: EventType("xiaozhi.ready")!)))
}

@Test("Xiaozhi keeps the home action separate from its typed voice presentation")
func projectsHomeActionAndTypedVoicePresentation() async throws {
    let module = XiaozhiModule()
    let runtime = ModuleRuntime()
    await runtime.register(module, enabled: true)
    await runtime.start(module.id)

    #expect(await module.currentPresentation() == .ready)
    let expanded = try #require(await runtime.contributions(for: module.id).first { $0.slot == .expandedContent })
    #expect(expanded.text == "Ready")
    #expect(expanded.actions.map(\.actionID) == [try #require(ActionID("xiaozhi.start"))])
    #expect(expanded.content == .home)

    let voice = XiaozhiConversationPresentation.listening.surfaceContent(ttsMuted: false)
    #expect(voice == .voice(.init(state: .listening, activity: .active)))
    #expect(
        XiaozhiConversationPresentation.speaking.surfaceContent(
            ttsMuted: true, assistantText: "Chào bạn")
            == .voice(
                .init(
                    state: .mutedText, assistantText: "Chào bạn", activity: .inactive)))

    await runtime.setEnabled(false, for: module.id)
    #expect(await runtime.contributions(for: module.id).isEmpty)
    #expect(await runtime.actions.definitions().isEmpty)
}

@Test("Home Start explicitly opens Xiaozhi and retains an Abort control on the surface")
func homeStartConnectsXiaozhiWithAbortControl() async throws {
    let transport = XiaozhiFakeVoiceTransport()
    let session = XiaozhiVoiceSession(
        connector: XiaozhiFakeVoiceConnector(transport: transport),
        capture: XiaozhiFakeAudioCapture(), playback: XiaozhiFakeAudioPlayback(), codec: XiaozhiFakeOpusCodec())
    let module = XiaozhiModule(
        bootstrap: XiaozhiFakeBootstrap(
            response: .init(
                websocket: .init(
                    url: URL(string: "wss://example.test/voice")!, token: "temporary-token", version: 1))),
        settingsProvider: { XiaozhiSettings(ttsMuted: true, deviceID: "02:11:22:33:44:55", clientID: "d1a6d617-337a-439a-ad02-5cf5c447a755") },
        voiceFactory: { session })
    let runtime = ModuleRuntime()
    await runtime.register(module, enabled: true)
    await runtime.start(module.id)
    await runtime.actions.invoke(try #require(ActionID("xiaozhi.start")))

    let expanded = try #require(await runtime.contributions(for: module.id).first { $0.slot == .expandedContent })
    #expect(expanded.actions.map(\.actionID) == [try #require(ActionID("xiaozhi.abort"))])
    #expect(expanded.content == .voice(.init(state: .connecting)))
    #expect(Set((await runtime.actions.definitions()).map(\.id)) == [
        try #require(ActionID("xiaozhi.prepare")), try #require(ActionID("xiaozhi.start")),
        try #require(ActionID("xiaozhi.abort")), try #require(ActionID("xiaozhi.retry")),
    ])
    await runtime.shutdown()
}

@Test("A failed Xiaozhi start stays visible on Surface with a retry action")
func failedStartRemainsVisibleOnSurface() async throws {
    let module = XiaozhiModule(
        bootstrap: XiaozhiFakeBootstrap(response: .init(activation: .init(message: "Activate this Mac"))),
        settingsProvider: { XiaozhiSettings(deviceID: "02:11:22:33:44:55", clientID: "d1a6d617-337a-439a-ad02-5cf5c447a755") },
        completionDelay: .zero)
    let runtime = ModuleRuntime()
    await runtime.register(module, enabled: true)
    await runtime.start(module.id)

    await runtime.actions.invoke(try #require(ActionID("xiaozhi.start")))
    for _ in 0..<10 { await Task.yield() }

    let expanded = try #require(await runtime.contributions(for: module.id).first { $0.slot == .expandedContent })
    #expect(await module.currentPresentation() == .error)
    #expect(expanded.content == .voice(.init(state: .error)))
    #expect(expanded.actions.map(\.actionID) == [try #require(ActionID("xiaozhi.retry"))])
    await runtime.shutdown()
}

@Test("Muted completion returns the Surface contribution to home")
func mutedCompletionReturnsSurfaceHome() async throws {
    let transport = XiaozhiFakeVoiceTransport()
    let session = XiaozhiVoiceSession(
        connector: XiaozhiFakeVoiceConnector(transport: transport),
        capture: XiaozhiFakeAudioCapture(), playback: XiaozhiFakeAudioPlayback(), codec: XiaozhiFakeOpusCodec())
    let module = XiaozhiModule(
        bootstrap: XiaozhiFakeBootstrap(
            response: .init(
                websocket: .init(
                    url: URL(string: "wss://example.test/voice")!, token: "temporary-token", version: 1))),
        settingsProvider: { XiaozhiSettings(ttsMuted: true, deviceID: "02:11:22:33:44:55", clientID: "d1a6d617-337a-439a-ad02-5cf5c447a755") },
        completionDelay: .zero, voiceFactory: { session })
    let runtime = ModuleRuntime()
    await runtime.register(module, enabled: true)
    await runtime.start(module.id)
    await runtime.actions.invoke(try #require(ActionID("xiaozhi.start")))
    try await session.receive(
        .text(
            """
            {"type":"hello","session_id":"session-1","audio_params":{"format":"opus","sample_rate":24000,"channels":1}}
            """))
    try await session.receive(.text("{\"type\":\"tts\",\"state\":\"stop\"}"))
    for _ in 0..<10 { await Task.yield() }

    let expanded = try #require(await runtime.contributions(for: module.id).first { $0.slot == .expandedContent })
    #expect(expanded.content == .home)
    #expect(expanded.actions.map(\.actionID) == [try #require(ActionID("xiaozhi.start"))])
    await runtime.shutdown()
}

@Test("Voice session sends authenticated hello then starts bounded Auto listening after server hello")
func startsAuthenticatedVoiceSession() async throws {
    let transport = XiaozhiFakeVoiceTransport()
    let capture = XiaozhiFakeAudioCapture()
    let session = XiaozhiVoiceSession(
        connector: XiaozhiFakeVoiceConnector(transport: transport),
        capture: capture,
        playback: XiaozhiFakeAudioPlayback(),
        codec: XiaozhiFakeOpusCodec())

    try await session.start(
        .init(
            url: URL(string: "wss://example.test/voice")!, token: "session-token", version: 1,
            deviceID: "02:11:22:33:44:55", clientID: "d1a6d617-337a-439a-ad02-5cf5c447a755",
            mode: .auto))

    let request = try #require(await transport.connectionRequest)
    #expect(request.headers["Authorization"] == "Bearer session-token")
    #expect(request.headers["Protocol-Version"] == "1")
    #expect(try await transport.jsonValue(at: 0, key: "type") == "hello")

    try await session.receive(
        .text(
            """
            {"type":"hello","session_id":"server-session","audio_params":{"format":"opus","sample_rate":24000,"channels":1,"frame_duration":60}}
            """))

    #expect((await session.snapshot()).sessionID == "server-session")
    #expect((await session.snapshot()).voiceState == .listening)
    #expect(await capture.isCapturing)
    #expect(try await transport.jsonValue(at: 1, key: "state") == "start")
}

@Test("Connection diagnostics send one microphone-free silence conversation after server hello")
func connectionDiagnosticConversation() async throws {
    let transport = XiaozhiFakeVoiceTransport()
    let session = XiaozhiVoiceSession(
        connector: XiaozhiFakeVoiceConnector(transport: transport),
        capture: XiaozhiFakeAudioCapture(), playback: XiaozhiFakeAudioPlayback(), codec: XiaozhiFakeOpusCodec())
    try await session.start(
        .init(
            url: URL(string: "wss://example.test/voice")!, token: "session-token", version: 1,
            deviceID: "02:11:22:33:44:55", clientID: "d1a6d617-337a-439a-ad02-5cf5c447a755",
            mode: .pushToTalk))
    try await session.receive(
        .text("{\"type\":\"hello\",\"session_id\":\"session-1\",\"audio_params\":{\"format\":\"opus\",\"sample_rate\":24000,\"channels\":1}}"))
    try await session.beginConnectionTestConversation()

    #expect(try await transport.jsonValue(at: 1, key: "type") == "listen")
    #expect(try await transport.jsonValue(at: 3, key: "state") == "stop")
    await session.stop()
}

@Test("WebSocket connector does not permit hello before the URLSession upgrade opens")
func waitsForWebSocketUpgradeBeforeHello() async throws {
    let gate = XiaozhiWebSocketOpenGate()
    let started = XiaozhiBooleanRecorder()
    let didOpen = XiaozhiBooleanRecorder()

    let waiting = Task {
        try await gate.waitUntilOpened { Task { await started.set() } }
        await didOpen.set()
    }
    for _ in 0..<10 where !(await started.value) { await Task.yield() }
    #expect(await started.value)
    #expect(!(await didOpen.value))

    await gate.opened()
    try await waiting.value
    #expect(await didOpen.value)
}

@Test("Muted Xiaozhi projects bounded assistant text and completes on tts stop")
func mutedSessionProjectsTextAndCompletion() async throws {
    let transport = XiaozhiFakeVoiceTransport()
    let events = XiaozhiVoiceEventRecorder()
    let session = XiaozhiVoiceSession(
        connector: XiaozhiFakeVoiceConnector(transport: transport),
        capture: XiaozhiFakeAudioCapture(), playback: XiaozhiFakeAudioPlayback(), codec: XiaozhiFakeOpusCodec())
    await session.setEventObserver { await events.record($0) }
    try await session.start(
        .init(
            url: URL(string: "wss://example.test/voice")!, token: "session-token", version: 1,
            deviceID: "02:11:22:33:44:55", clientID: "d1a6d617-337a-439a-ad02-5cf5c447a755",
            mode: .auto, ttsMuted: true))
    try await session.receive(
        .text(
            """
            {"type":"hello","session_id":"session-1","audio_params":{"format":"opus","sample_rate":24000,"channels":1}}
            """))
    try await session.receive(
        .text(
            """
            {"type":"tts","state":"start","text":"Chào bạn"}
            """))
    try await session.receive(
        .text(
            """
            {"type":"tts","state":"stop"}
            """))

    #expect(
        await events.events == [
            .state(.listening), .assistantText("Chào bạn"), .state(.speaking), .ttsStopped, .completed, .state(.idle),
        ])
    await session.stop()
}

@Test("Audible Xiaozhi waits for playback drain after tts stop")
func audibleSessionWaitsForPlaybackDrain() async throws {
    let transport = XiaozhiFakeVoiceTransport()
    let playback = XiaozhiManualDrainPlayback()
    let events = XiaozhiVoiceEventRecorder()
    let session = XiaozhiVoiceSession(
        connector: XiaozhiFakeVoiceConnector(transport: transport),
        capture: XiaozhiFakeAudioCapture(), playback: playback, codec: XiaozhiFakeOpusCodec())
    await session.setEventObserver { await events.record($0) }
    try await session.start(
        .init(
            url: URL(string: "wss://example.test/voice")!, token: "session-token", version: 1,
            deviceID: "02:11:22:33:44:55", clientID: "d1a6d617-337a-439a-ad02-5cf5c447a755", mode: .auto))
    try await session.receive(
        .text(
            """
            {"type":"hello","session_id":"session-1","audio_params":{"format":"opus","sample_rate":24000,"channels":1}}
            """))
    try await session.receive(.text("{\"type\":\"tts\",\"state\":\"start\"}"))
    try await session.receive(.binary(Data(repeating: 0, count: 8)))
    await Task.yield()
    try await session.receive(.text("{\"type\":\"tts\",\"state\":\"stop\"}"))
    #expect(!(await events.events.contains(.completed)))

    await playback.drain()
    #expect(await events.events.contains(.completed))
    await session.stop()
}

@Test("Push-to-Talk only captures while held and uplink drops stale frames beyond 2400 ms")
func boundsPushToTalkAudio() async throws {
    let transport = XiaozhiFakeVoiceTransport()
    let capture = XiaozhiFakeAudioCapture()
    let session = XiaozhiVoiceSession(
        connector: XiaozhiFakeVoiceConnector(transport: transport), capture: capture,
        playback: XiaozhiFakeAudioPlayback(), codec: XiaozhiFakeOpusCodec())
    try await session.start(
        .init(
            url: URL(string: "wss://example.test/voice")!, token: "session-token", version: 1,
            deviceID: "02:11:22:33:44:55", clientID: "d1a6d617-337a-439a-ad02-5cf5c447a755",
            mode: .pushToTalk))
    try await session.receive(
        .text(
            "{"
                + "\"type\":\"hello\",\"session_id\":\"server-session\",\"audio_params\":{\"format\":\"opus\",\"sample_rate\":16000,\"channels\":1,\"frame_duration\":60}}"
        ))

    #expect(!(await capture.isCapturing))
    try await session.beginPushToTalk()
    #expect(await capture.isCapturing)
    for frame in 0..<41 { try await session.enqueueMicrophonePCM(Data(repeating: UInt8(frame), count: 1_920)) }
    try await session.endPushToTalk()

    #expect(!(await capture.isCapturing))
    #expect((await session.snapshot()).droppedUplinkFrames == 1)
    #expect(try await transport.lastJSONValue(key: "state") == "stop")
}

@Test("Malformed server input fails closed and playback drops stale packets beyond 1200 ms")
func rejectsMalformedInputAndBoundsPlayback() async throws {
    let playback = XiaozhiFakeAudioPlayback()
    let session = XiaozhiVoiceSession(
        connector: XiaozhiFakeVoiceConnector(transport: XiaozhiFakeVoiceTransport()),
        capture: XiaozhiFakeAudioCapture(), playback: playback, codec: XiaozhiFakeOpusCodec())
    try await session.start(
        .init(
            url: URL(string: "wss://example.test/voice")!, token: "secret-token", version: 1,
            deviceID: "02:11:22:33:44:55", clientID: "d1a6d617-337a-439a-ad02-5cf5c447a755",
            mode: .auto))

    do {
        try await session.receive(.text("{not-json}"))
        Issue.record("Malformed input must fail closed")
    } catch let error as XiaozhiVoiceSessionError {
        #expect(error == .malformedMessage)
    }
    #expect((await session.snapshot()).voiceState == .error)
    #expect((await session.snapshot()).lastError == "Protocol error.")
    #expect(!(await session.snapshot()).description.contains("secret-token"))
    #expect(await playback.stopCount >= 2)
}

private actor XiaozhiMemorySettingsBackend: SettingsBackend {
    private var active: Data?

    func readActive() async throws -> Data? { active }
    func replaceActive(with data: Data) async throws { active = data }
    func quarantine(_: Data) async throws {}
}

private struct XiaozhiFakeBootstrap: XiaozhiBootstrapping {
    let response: XiaozhiBootstrapResponse
    func bootstrap(_: XiaozhiBootstrapRequest) async throws -> XiaozhiBootstrapResponse { response }
}

private struct XiaozhiFailingBootstrap: XiaozhiBootstrapping {
    func bootstrap(_: XiaozhiBootstrapRequest) async throws -> XiaozhiBootstrapResponse {
        throw URLError(.notConnectedToInternet)
    }
}

private struct XiaozhiHTTPFailingBootstrap: XiaozhiBootstrapping {
    func bootstrap(_: XiaozhiBootstrapRequest) async throws -> XiaozhiBootstrapResponse {
        throw XiaozhiBootstrapError.httpStatus(400)
    }
}

private struct XiaozhiTestVoiceFactoryError: Error {}

private actor XiaozhiFakeVoiceTransport: XiaozhiVoiceTransport {
    private(set) var connectionRequest: XiaozhiVoiceConnectionRequest?
    private var messages: [XiaozhiVoiceTransportMessage] = []

    func record(_ request: XiaozhiVoiceConnectionRequest) { connectionRequest = request }
    func send(_ message: XiaozhiVoiceTransportMessage) async throws { messages.append(message) }
    func nextMessage() async throws -> XiaozhiVoiceTransportMessage {
        try await Task.sleep(for: .seconds(3_600))
        throw CancellationError()
    }
    func disconnect() async {}

    func jsonValue(at index: Int, key: String) throws -> String? {
        guard messages.indices.contains(index), case .text(let text) = messages[index] else { return nil }
        return (try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])?[key] as? String
    }

    func lastJSONValue(key: String) throws -> String? {
        guard let message = messages.last, case .text(let text) = message else { return nil }
        return (try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])?[key] as? String
    }
}

private struct XiaozhiFakeVoiceConnector: XiaozhiVoiceConnecting {
    let transport: XiaozhiFakeVoiceTransport
    func connect(_ request: XiaozhiVoiceConnectionRequest) async throws -> any XiaozhiVoiceTransport {
        await transport.record(request)
        return transport
    }
}

private struct XiaozhiFailingVoiceConnector: XiaozhiVoiceConnecting {
    func connect(_: XiaozhiVoiceConnectionRequest) async throws -> any XiaozhiVoiceTransport {
        throw URLError(.networkConnectionLost)
    }
}

private struct XiaozhiBridgedFailingVoiceConnector: XiaozhiVoiceConnecting {
    func connect(_: XiaozhiVoiceConnectionRequest) async throws -> any XiaozhiVoiceTransport {
        throw NSError(domain: NSURLErrorDomain, code: URLError.networkConnectionLost.rawValue)
    }
}

private struct XiaozhiDisconnectingVoiceConnector: XiaozhiVoiceConnecting {
    func connect(_: XiaozhiVoiceConnectionRequest) async throws -> any XiaozhiVoiceTransport {
        XiaozhiDisconnectingVoiceTransport()
    }
}

private actor XiaozhiDisconnectingVoiceTransport: XiaozhiVoiceTransport {
    func send(_: XiaozhiVoiceTransportMessage) async throws {}
    func nextMessage() async throws -> XiaozhiVoiceTransportMessage { throw URLError(.networkConnectionLost) }
    func disconnect() async {}
}

private actor XiaozhiFakeAudioCapture: XiaozhiAudioCapturing {
    private(set) var isCapturing = false
    func start(_: @escaping @Sendable (Data) -> Void) async throws { isCapturing = true }
    func stop() async { isCapturing = false }
}

private actor XiaozhiFakeAudioPlayback: XiaozhiAudioPlaying {
    private(set) var stopCount = 0
    func enqueue(_: Data, sampleRate _: Int, channels _: Int) async throws {}
    func setDrainedObserver(_: @escaping @Sendable () async -> Void) async {}
    func stop() async { stopCount += 1 }
}

private actor XiaozhiManualDrainPlayback: XiaozhiAudioPlaying {
    private var observer: (@Sendable () async -> Void)?
    func enqueue(_: Data, sampleRate _: Int, channels _: Int) async throws {}
    func setDrainedObserver(_ observer: @escaping @Sendable () async -> Void) async { self.observer = observer }
    func drain() async { await observer?() }
    func stop() async {}
}

private actor XiaozhiVoiceEventRecorder {
    private(set) var events: [XiaozhiVoiceSessionEvent] = []
    func record(_ event: XiaozhiVoiceSessionEvent) { events.append(event) }
}

private actor XiaozhiBooleanRecorder {
    private(set) var value = false
    func set() { value = true }
}

private struct XiaozhiFakeOpusCodec: XiaozhiOpusCoding {
    func encode(_ pcm16kMono: Data) throws -> Data { pcm16kMono }
    func decode(_ packet: Data, sampleRate _: Int, channels _: Int) throws -> Data { packet }
}
