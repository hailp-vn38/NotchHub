import Foundation
import NotchCore
import NotchDomain

public enum XiaozhiDiagnostics {
    private static let secretKeys: Set<String> = ["authorization", "credential", "secret", "token"]

    public static func redact(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return Dictionary(
                uniqueKeysWithValues: dictionary.map { key, value in
                    (key, secretKeys.contains(key.lowercased()) ? "[REDACTED]" : redact(value))
                })
        }
        if let array = value as? [Any] { return array.map(redact) }
        return value
    }
}

public struct XiaozhiBootstrapRequest: Encodable, Sendable {
    public let deviceID: String
    public let clientID: String
    public let language: String
    public let appVersion: String

    public init(deviceID: String, clientID: String, language: String = "en", appVersion: String) {
        self.deviceID = deviceID
        self.clientID = clientID
        self.language = language
        self.appVersion = appVersion
    }

    enum CodingKeys: String, CodingKey { case version, language, uuid, application }
    enum ApplicationKeys: String, CodingKey { case name, version }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(2, forKey: .version)
        try container.encode(language, forKey: .language)
        try container.encode(clientID, forKey: .uuid)
        var application = container.nestedContainer(keyedBy: ApplicationKeys.self, forKey: .application)
        try application.encode("NotchHub", forKey: .name)
        try application.encode(appVersion, forKey: .version)
    }
}

public struct XiaozhiActivation: Decodable, Equatable, Sendable {
    public let message: String?
    public let code: String?
    public let challenge: String?

    public init(message: String? = nil, code: String? = nil, challenge: String? = nil) {
        self.message = message
        self.code = code
        self.challenge = challenge
    }
}

public struct XiaozhiBootstrapResponse: Decodable, Equatable, Sendable {
    public struct WebSocket: Decodable, Equatable, Sendable {
        public let url: URL
        public let token: String
        public let version: Int

        public init(url: URL, token: String, version: Int) {
            self.url = url
            self.token = token
            self.version = version
        }

        private enum CodingKeys: String, CodingKey { case url, token, version }

        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            url = try values.decode(URL.self, forKey: .url)
            token = try values.decode(String.self, forKey: .token)
            version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        }
    }

    public let activation: XiaozhiActivation?
    public let websocket: WebSocket?

    public init(activation: XiaozhiActivation? = nil, websocket: WebSocket? = nil) {
        self.activation = activation
        self.websocket = websocket
    }
}

public protocol XiaozhiBootstrapping: Sendable {
    func bootstrap(_ request: XiaozhiBootstrapRequest) async throws -> XiaozhiBootstrapResponse
}

public enum XiaozhiBootstrapError: Error, Equatable, Sendable {
    case httpStatus(Int)
}

/// Direct HTTP bootstrap boundary. The returned token is deliberately kept in
/// the response only; callers store it in Keychain when persistence is needed.
public struct XiaozhiCloudBootstrapClient: XiaozhiBootstrapping {
    public static let defaultEndpoint = URL(string: "https://api.tenclass.net/xiaozhi/ota/")!
    private let endpoint: URL
    private let session: URLSession

    public init(endpoint: URL = defaultEndpoint, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    public func bootstrap(_ request: XiaozhiBootstrapRequest) async throws -> XiaozhiBootstrapResponse {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("1", forHTTPHeaderField: "Activation-Version")
        urlRequest.setValue(request.deviceID, forHTTPHeaderField: "Device-Id")
        urlRequest.setValue(request.clientID, forHTTPHeaderField: "Client-Id")
        urlRequest.setValue("NotchHub/\(request.appVersion) macOS", forHTTPHeaderField: "User-Agent")
        urlRequest.setValue(request.language, forHTTPHeaderField: "Accept-Language")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard 200..<300 ~= http.statusCode else { throw XiaozhiBootstrapError.httpStatus(http.statusCode) }
        return try JSONDecoder().decode(XiaozhiBootstrapResponse.self, from: data)
    }
}

public actor XiaozhiModule: NotchModule {
    public nonisolated let id = ModuleID("xiaozhi")!
    public nonisolated let metadata = ModuleMetadata(
        displayName: "Native Xiaozhi Client", version: "0.1.0",
        supportedSurfaceSlots: [.indicator, .compactStatus, .expandedContent],
        requiredCapabilities: [Capability("microphone")!])

    private let bootstrap: any XiaozhiBootstrapping
    private let bootstrapFactory: (@Sendable (URL) -> any XiaozhiBootstrapping)?
    private let voiceFactory: @Sendable () throws -> XiaozhiVoiceSession
    private let permissionCoordinator: PermissionCoordinator?
    private let settingsProvider: @Sendable () async -> XiaozhiSettings
    private var voice: XiaozhiVoiceSession?
    private var lifetime: ModuleLifetime?
    private var presentation = XiaozhiConversationPresentation.ready
    private var isVoiceMode = false
    private var sessionTTSMuted = false
    private var assistantText: String?
    private var voiceGeneration = 0
    private var completionTask: Task<Void, Never>?
    private var completionGeneration = 0
    private let completionDelay: Duration

    public init(
        bootstrap: any XiaozhiBootstrapping = XiaozhiCloudBootstrapClient(),
        bootstrapFactory: (@Sendable (URL) -> any XiaozhiBootstrapping)? = nil,
        permissionCoordinator: PermissionCoordinator? = nil,
        settingsProvider: @escaping @Sendable () async -> XiaozhiSettings = { .init() },
        completionDelay: Duration = .seconds(3),
        voiceFactory: @escaping @Sendable () throws -> XiaozhiVoiceSession = {
            try XiaozhiVoiceSession(
                connector: XiaozhiURLSessionVoiceConnector(), capture: XiaozhiAVAudioCapture(),
                playback: XiaozhiAVAudioPlayback(), codec: XiaozhiOpusCodec())
        }
    ) {
        self.bootstrap = bootstrap
        self.bootstrapFactory = bootstrapFactory
        self.voiceFactory = voiceFactory
        self.permissionCoordinator = permissionCoordinator
        self.settingsProvider = settingsProvider
        self.completionDelay = completionDelay
    }

    public func start(context: ModuleContext) async throws {
        lifetime = context.lifetime
        await context.lifetime.register(.init(moduleID: id, slot: .indicator, text: "Xiaozhi"))
        await publishPresentation()
        let prepare = ModuleAction(
            definition: .init(id: ActionID("xiaozhi.prepare")!, title: "Prepare Xiaozhi"),
            invoke: { [weak self, eventPublisher = context.eventPublisher] in
                await self?.prepare(eventPublisher: eventPublisher)
            }
        )
        _ = await context.actions.register(prepare, lifetime: context.lifetime)
        let start = ModuleAction(
            definition: .init(id: ActionID("xiaozhi.start")!, title: "Start Xiaozhi"),
            invoke: { [weak self, eventPublisher = context.eventPublisher] in
                await self?.startVoice(eventPublisher: eventPublisher)
            }
        )
        _ = await context.actions.register(start, lifetime: context.lifetime)
        for (id, title) in [
            ("xiaozhi.abort", "Abort Xiaozhi"),
            ("xiaozhi.retry", "Retry Xiaozhi"),
        ] {
            let action = ModuleAction(
                definition: .init(id: ActionID(id)!, title: title),
                invoke: { [weak self, eventPublisher = context.eventPublisher] in
                    await self?.control(id, eventPublisher: eventPublisher)
                })
            _ = await context.actions.register(action, lifetime: context.lifetime)
        }
        await context.lifetime.register(.socket, named: "xiaozhi.voice") { [weak self] in
            await self?.stopVoiceSession()
        }
    }

    private func prepare(eventPublisher: any ModuleEventPublisher) async {
        do {
            let settings = await settingsProvider()
            guard settings.isValid, let endpoint = URL(string: settings.bootstrapURL) else { throw URLError(.badURL) }
            let client = bootstrapFactory?(endpoint) ?? bootstrap
            let response = try await client.bootstrap(
                .init(
                    deviceID: settings.deviceID, clientID: settings.clientID, appVersion: "0.1.0"))
            let type = response.activation == nil ? "xiaozhi.ready" : "xiaozhi.activationRequired"
            await eventPublisher.publish(.init(moduleID: id, type: EventType(type)!))
        } catch {
            await showFailure("xiaozhi.bootstrapFailed", eventPublisher: eventPublisher)
        }
    }

    private func startVoice(eventPublisher: any ModuleEventPublisher) async {
        do {
            cancelCompletion()
            isVoiceMode = true
            if let permissionCoordinator {
                await permissionCoordinator.refresh()
                guard await permissionCoordinator.snapshot().row(for: .microphone)?.status == .authorized else {
                    await showFailure("xiaozhi.microphoneDenied", eventPublisher: eventPublisher)
                    return
                }
            }
            let settings = await settingsProvider()
            guard settings.isValid, let endpoint = URL(string: settings.bootstrapURL) else { throw URLError(.badURL) }
            sessionTTSMuted = settings.ttsMuted
            assistantText = nil
            presentation = .connecting
            await publishPresentation()
            let deviceID = settings.deviceID
            let clientID = settings.clientID
            let client = bootstrapFactory?(endpoint) ?? bootstrap
            let response = try await client.bootstrap(
                .init(deviceID: deviceID, clientID: clientID, appVersion: "0.1.0"))
            guard let websocket = response.websocket else {
                await showFailure("xiaozhi.activationRequired", eventPublisher: eventPublisher)
                return
            }
            let voice = try voiceFactory()
            voiceGeneration &+= 1
            let generation = voiceGeneration
            await voice.setEventObserver { [weak self] event in
                await self?.receiveVoiceEvent(event, generation: generation)
            }
            self.voice = voice
            try await voice.start(
                .init(
                    url: websocket.url, token: websocket.token, version: websocket.version,
                    deviceID: deviceID, clientID: clientID, mode: settings.conversationMode, ttsMuted: sessionTTSMuted))
            presentation = .connecting
            await publishPresentation()
            await eventPublisher.publish(.init(moduleID: id, type: EventType("xiaozhi.connecting")!))
        } catch {
            await showFailure("xiaozhi.connectionFailed", eventPublisher: eventPublisher)
        }
    }

    public func currentPresentation() -> XiaozhiConversationPresentation { presentation }

    public func handle(_ command: ModuleCommand) async throws -> ModuleCommandResult {
        switch command {
        case .simulateFailure:
            return .ignored
        case .endTransientSession:
            guard isVoiceMode else { return .ignored }
            await returnHomeNow()
            return .handled
        }
    }

    private func receiveVoiceEvent(_ event: XiaozhiVoiceSessionEvent, generation: Int) async {
        guard generation == voiceGeneration else { return }
        switch event {
        case .state(let voiceState):
            presentation = .init(voiceState: voiceState)
        case .assistantText(let text): assistantText = text
        case .opusReceived, .ttsStopped: break
        case .completed:
            presentation = .ready
            scheduleReturnHome()
        }
        await publishPresentation()
    }

    /// Publishes only a typed, retryable error state. Transport and server
    /// details can contain sensitive values, so they remain out of Surface.
    private func showFailure(_ eventType: String, eventPublisher: any ModuleEventPublisher) async {
        cancelCompletion()
        presentation = .error
        await publishPresentation()
        await eventPublisher.publish(.init(moduleID: id, type: EventType(eventType)!))
    }

    private func control(_ action: String, eventPublisher: any ModuleEventPublisher) async {
        switch action {
        case "xiaozhi.abort":
            try? await voice?.abort()
            await returnHomeNow()
            await eventPublisher.publish(.init(moduleID: id, type: EventType("xiaozhi.aborted")!))
        case "xiaozhi.retry":
            await returnHomeNow()
            await startVoice(eventPublisher: eventPublisher)
        default: break
        }
    }

    private func publishPresentation() async {
        guard let lifetime else { return }
        await lifetime.update(.init(moduleID: id, slot: .compactStatus, text: presentation.compactText))
        await lifetime.update(
            .init(
                moduleID: id, slot: .expandedContent, text: presentation.expandedText,
                actions: presentation.actions,
                content: isVoiceMode
                    ? presentation.surfaceContent(ttsMuted: sessionTTSMuted, assistantText: assistantText)
                    : .home))
    }

    public func stop() async {
        await stopVoiceSession()
        lifetime = nil
        presentation = .ready
    }

    private func scheduleReturnHome() {
        cancelCompletion()
        completionGeneration &+= 1
        let generation = completionGeneration
        completionTask = Task { [weak self] in
            try? await Task.sleep(for: self?.completionDelay ?? .zero)
            await self?.returnHome(generation: generation)
        }
    }

    private func cancelCompletion() {
        completionGeneration &+= 1
        completionTask?.cancel()
        completionTask = nil
    }

    private func returnHome(generation: Int) async {
        guard generation == completionGeneration else { return }
        await returnHomeNow()
    }

    private func returnHomeNow() async {
        cancelCompletion()
        await stopVoiceSession()
        isVoiceMode = false
        sessionTTSMuted = false
        assistantText = nil
        presentation = .ready
        await publishPresentation()
    }

    private func stopVoiceSession() async {
        cancelCompletion()
        voiceGeneration &+= 1
        await voice?.stop()
        voice = nil
        assistantText = nil
    }
}

public enum XiaozhiConnectionTestError: Error, Equatable, Sendable {
    case invalidSettings
    case activationRequired
    case alreadyRunning
    case timedOut
    case connectionFailed
}

/// A disposable Settings diagnostic. It never uses the Module runtime,
/// microphone, surface, Keychain, or a persisted credential.
public actor XiaozhiConnectionTester: XiaozhiConnectionTesting {
    private let bootstrapFactory: @Sendable (URL) -> any XiaozhiBootstrapping
    private let voiceFactory: @Sendable () throws -> XiaozhiVoiceSession
    private var continuation: CheckedContinuation<XiaozhiConnectionTestReport, Error>?
    private var progress: (@Sendable (XiaozhiConnectionTestStep) async -> Void)?
    private var pendingResult: XiaozhiConnectionTestReport?
    private var pendingError: Error?
    private var version = 1

    public init(
        bootstrapFactory: @escaping @Sendable (URL) -> any XiaozhiBootstrapping = { XiaozhiCloudBootstrapClient(endpoint: $0) },
        voiceFactory: @escaping @Sendable () throws -> XiaozhiVoiceSession = {
            try XiaozhiVoiceSession(
                connector: XiaozhiURLSessionVoiceConnector(), capture: XiaozhiSilentAudioCapture(),
                playback: XiaozhiAVAudioPlayback(), codec: XiaozhiOpusCodec())
        }
    ) {
        self.bootstrapFactory = bootstrapFactory
        self.voiceFactory = voiceFactory
    }

    public func testConnection(
        settings: XiaozhiSettings,
        progress: @escaping @Sendable (XiaozhiConnectionTestStep) async -> Void
    ) async throws -> XiaozhiConnectionTestReport {
        guard settings.isValid, let endpoint = URL(string: settings.bootstrapURL) else {
            throw XiaozhiConnectionTestError.invalidSettings
        }
        guard continuation == nil else { throw XiaozhiConnectionTestError.alreadyRunning }
        self.progress = progress
        await progress(.configurationValid)
        let response: XiaozhiBootstrapResponse
        do {
            response = try await bootstrapFactory(endpoint).bootstrap(
                .init(deviceID: settings.deviceID, clientID: settings.clientID, appVersion: "0.1.0"))
        } catch let error as XiaozhiBootstrapError {
            let detail = switch error { case .httpStatus(let status): "Bootstrap rejected the request (HTTP \(status))." }
            throw XiaozhiConnectionTestFailure(detail: detail)
        } catch let error as URLError {
            throw XiaozhiConnectionTestFailure(detail: "Bootstrap request failed: \(error.localizedDescription)")
        } catch {
            throw XiaozhiConnectionTestFailure(detail: "Bootstrap request failed. Check the Bootstrap URL and network connection.")
        }
        if let code = response.activation?.code,
            code.range(of: "^[0-9]{6}$", options: .regularExpression) != nil
        {
            throw XiaozhiActivationRequired(code: code)
        }
        guard let websocket = response.websocket else {
            throw XiaozhiConnectionTestError.activationRequired
        }
        version = websocket.version
        let voice: XiaozhiVoiceSession
        do {
            voice = try voiceFactory()
            await voice.setEventObserver { [weak self, weak voice] event in
                guard let voice else { return }
                await self?.observe(event, voice: voice)
            }
            try await voice.start(
                .init(
                    url: websocket.url, token: websocket.token, version: websocket.version,
                    deviceID: settings.deviceID, clientID: settings.clientID, mode: .pushToTalk))
        } catch let error as URLError {
            reset()
            throw XiaozhiConnectionTestFailure(detail: Self.webSocketFailureDetail(for: error))
        } catch {
            reset()
            throw XiaozhiConnectionTestFailure(
                detail: "WebSocket connection failed before Xiaozhi could receive hello.")
        }
        await progress(.webSocketConnected)
        await progress(.helloSent)
        do {
            let report = try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                if let pendingResult {
                    self.pendingResult = nil
                    self.continuation = nil
                    continuation.resume(returning: pendingResult)
                    return
                }
                if let pendingError {
                    self.pendingError = nil
                    self.continuation = nil
                    continuation.resume(throwing: pendingError)
                    return
                }
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(20))
                    await self?.timeout()
                }
            }
            await voice.stop()
            reset()
            return report
        } catch {
            await voice.stop()
            reset()
            throw error
        }
    }

    private func observe(_ event: XiaozhiVoiceSessionEvent, voice: XiaozhiVoiceSession) async {
        switch event {
        case .state(.idle):
            await progress?(.serverHelloReceived)
            do {
                try await voice.beginConnectionTestConversation()
                await progress?(.testConversationStarted)
            } catch {
                fail(XiaozhiConnectionTestFailure(
                    detail: "Could not start the microphone-free Xiaozhi test conversation."))
            }
        case .state(.speaking): await progress?(.ttsStarted)
        case .state(.error):
            fail(XiaozhiConnectionTestFailure(
                detail: "Xiaozhi server closed the WebSocket before sending Server Hello."))
        case .opusReceived: await progress?(.opusReceived)
        case .ttsStopped: await progress?(.ttsStopped)
        case .completed:
            await progress?(.playbackDrained)
            succeed(.init(protocolVersion: version, audioDescription: "Opus · negotiated · Mono"))
        case .state, .assistantText: break
        }
    }

    private func timeout() {
        fail(XiaozhiConnectionTestFailure(
            detail: "Timed out waiting for Xiaozhi Server Hello."))
    }

    private static func webSocketFailureDetail(for error: URLError) -> String {
        switch error.code {
        case .networkConnectionLost:
            "WebSocket connection was closed before Xiaozhi could receive hello."
        case .notConnectedToInternet:
            "No Internet connection is available for the Xiaozhi WebSocket test."
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            "Could not reach the Xiaozhi WebSocket host. Check the Bootstrap URL and network connection."
        case .timedOut:
            "WebSocket connection timed out before Xiaozhi could receive hello."
        default:
            "WebSocket connection failed before Xiaozhi could receive hello."
        }
    }

    private func succeed(_ result: XiaozhiConnectionTestReport) {
        guard let continuation else { pendingResult = result; return }
        continuation.resume(returning: result)
        self.continuation = nil
    }
    private func fail(_ error: Error) {
        guard let continuation else { pendingError = error; return }
        continuation.resume(throwing: error)
        self.continuation = nil
    }
    private func reset() { continuation = nil; progress = nil; pendingResult = nil; pendingError = nil }
}

/// The only conversation information released to presentation. It contains no
/// session identifier, credential, audio packet, transport error, or history.
public enum XiaozhiConversationPresentation: Equatable, Sendable {
    case ready, connecting, listening, thinking, speaking, error

    init(voiceState: XiaozhiVoiceState) {
        switch voiceState {
        case .ready, .idle: self = .ready
        case .connecting, .handshaking: self = .connecting
        case .listening: self = .listening
        case .thinking: self = .thinking
        case .speaking: self = .speaking
        case .error: self = .error
        }
    }

    public var compactText: String { "Xiaozhi \(expandedText)" }

    public var expandedText: String {
        switch self {
        case .ready: "Ready"
        case .connecting: "Connecting"
        case .listening: "Listening"
        case .thinking: "Thinking"
        case .speaking: "Speaking"
        case .error: "Connection failed"
        }
    }

    public var actions: [SurfaceActionDescriptor] {
        let make = { (id: String, title: String) in SurfaceActionDescriptor(actionID: ActionID(id)!, title: title) }
        return switch self {
        case .ready: [make("xiaozhi.start", "Start")]
        case .connecting, .listening, .thinking, .speaking: [make("xiaozhi.abort", "Abort")]
        case .error: [make("xiaozhi.retry", "Retry")]
        }
    }

    public func surfaceContent(ttsMuted: Bool, assistantText: String? = nil) -> SurfaceContent {
        if ttsMuted, self == .speaking {
            return .voice(.init(state: .mutedText, assistantText: assistantText, activity: .inactive))
        }
        let state: SurfaceVoiceState =
            switch self {
            case .ready: .completed
            case .connecting: .connecting
            case .listening: .listening
            case .thinking: .thinking
            case .speaking: .speaking
            case .error: .error
            }
        return .voice(
            .init(
                state: state,
                assistantText: assistantText,
                activity: self == .listening || self == .speaking ? .active : .inactive))
    }
}
