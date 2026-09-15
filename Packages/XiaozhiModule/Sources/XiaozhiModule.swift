import Foundation
import NotchCore
import NotchDomain
import Security

public protocol XiaozhiCredentialStoring: Sendable {
    func credential() throws -> String?
    func saveCredential(_ value: String) throws
    func removeCredential() throws
}

public enum XiaozhiCredentialStoreError: Error, Equatable, Sendable {
    case invalidCredential
    case keychainFailure(OSStatus)
}

/// The only durable boundary for Xiaozhi credentials. Secrets never enter
/// `AppSettings`, module health, surface descriptors, or diagnostics.
public struct KeychainXiaozhiCredentialStore: XiaozhiCredentialStoring {
    private let service = "com.notchhub.xiaozhi"
    private let account = "credential"

    public init() {}

    public func credential() throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
            let credential = String(data: data, encoding: .utf8)
        else { throw XiaozhiCredentialStoreError.keychainFailure(status) }
        return credential
    }

    public func saveCredential(_ value: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw XiaozhiCredentialStoreError.invalidCredential
        }
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var create = query
            create[kSecValueData] = data
            let createStatus = SecItemAdd(create as CFDictionary, nil)
            guard createStatus == errSecSuccess else {
                throw XiaozhiCredentialStoreError.keychainFailure(createStatus)
            }
        } else if status != errSecSuccess {
            throw XiaozhiCredentialStoreError.keychainFailure(status)
        }
    }

    public func removeCredential() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw XiaozhiCredentialStoreError.keychainFailure(status)
        }
    }
}

public protocol XiaozhiIdentityStoring: Sendable {
    func deviceID() throws -> String
    func clientID() throws -> String
}

/// Generates one locally-administered unicast MAC ID, then keeps it in
/// Keychain so identity is stable without becoming Settings/export data.
public struct KeychainXiaozhiIdentityStore: XiaozhiIdentityStoring {
    private let service = "com.notchhub.xiaozhi"

    public init() {}

    public func deviceID() throws -> String {
        try persistentValue(account: "device-id", isValid: XiaozhiIdentity.isValidDeviceID) {
            XiaozhiIdentity.randomDeviceID()
        }
    }

    public func clientID() throws -> String {
        try persistentValue(account: "client-id", isValid: XiaozhiIdentity.isValidClientID) {
            UUID().uuidString.lowercased()
        }
    }

    private func persistentValue(
        account: String,
        isValid: (String) -> Bool,
        generate: () -> String
    ) throws -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data,
            let existing = String(data: data, encoding: .utf8), XiaozhiIdentity.isValidDeviceID(existing)
        {
            return existing
        }
        guard status == errSecItemNotFound else { throw XiaozhiCredentialStoreError.keychainFailure(status) }
        let generated = generate()
        var create = query
        create.removeValue(forKey: kSecReturnData)
        create.removeValue(forKey: kSecMatchLimit)
        create[kSecValueData] = Data(generated.utf8)
        let createStatus = SecItemAdd(create as CFDictionary, nil)
        guard createStatus == errSecSuccess else {
            throw XiaozhiCredentialStoreError.keychainFailure(createStatus)
        }
        return generated
    }
}

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
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
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
    private let credentials: any XiaozhiCredentialStoring
    private let identity: any XiaozhiIdentityStoring
    private let voiceFactory: @Sendable () throws -> XiaozhiVoiceSession
    private let permissionCoordinator: PermissionCoordinator?
    private let ttsMutedProvider: @Sendable () async -> Bool
    private var voice: XiaozhiVoiceSession?
    private var lifetime: ModuleLifetime?
    private var presentation = XiaozhiConversationPresentation.ready
    private var isVoiceMode = false
    private var sessionTTSMuted = false
    private var assistantText: String?
    private var completionTask: Task<Void, Never>?
    private var completionGeneration = 0
    private let completionDelay: Duration

    public init(
        bootstrap: any XiaozhiBootstrapping = XiaozhiCloudBootstrapClient(),
        credentials: any XiaozhiCredentialStoring = KeychainXiaozhiCredentialStore(),
        identity: any XiaozhiIdentityStoring = KeychainXiaozhiIdentityStore(),
        permissionCoordinator: PermissionCoordinator? = nil,
        ttsMutedProvider: @escaping @Sendable () async -> Bool = { false },
        completionDelay: Duration = .seconds(3),
        voiceFactory: @escaping @Sendable () throws -> XiaozhiVoiceSession = {
            try XiaozhiVoiceSession(
                connector: XiaozhiURLSessionVoiceConnector(), capture: XiaozhiAVAudioCapture(),
                playback: XiaozhiAVAudioPlayback(), codec: XiaozhiOpusCodec())
        }
    ) {
        self.bootstrap = bootstrap
        self.credentials = credentials
        self.identity = identity
        self.voiceFactory = voiceFactory
        self.permissionCoordinator = permissionCoordinator
        self.ttsMutedProvider = ttsMutedProvider
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
            let response = try await bootstrap.bootstrap(
                .init(
                    deviceID: try identity.deviceID(), clientID: try identity.clientID(), appVersion: "0.1.0"))
            if let token = response.websocket?.token { try credentials.saveCredential(token) }
            let type = response.activation == nil ? "xiaozhi.ready" : "xiaozhi.activationRequired"
            await eventPublisher.publish(.init(moduleID: id, type: EventType(type)!))
        } catch {
            await eventPublisher.publish(.init(moduleID: id, type: EventType("xiaozhi.bootstrapFailed")!))
        }
    }

    private func startVoice(eventPublisher: any ModuleEventPublisher) async {
        do {
            if let permissionCoordinator {
                await permissionCoordinator.refresh()
                guard await permissionCoordinator.snapshot().row(for: .microphone)?.status == .authorized else {
                    await eventPublisher.publish(.init(moduleID: id, type: EventType("xiaozhi.microphoneDenied")!))
                    return
                }
            }
            cancelCompletion()
            sessionTTSMuted = await ttsMutedProvider()
            assistantText = nil
            isVoiceMode = true
            presentation = .connecting
            await publishPresentation()
            let deviceID = try identity.deviceID()
            let clientID = try identity.clientID()
            let response = try await bootstrap.bootstrap(
                .init(deviceID: deviceID, clientID: clientID, appVersion: "0.1.0"))
            guard let websocket = response.websocket else {
                presentation = .error
                await publishPresentation()
                await eventPublisher.publish(.init(moduleID: id, type: EventType("xiaozhi.activationRequired")!))
                scheduleReturnHome()
                return
            }
            try credentials.saveCredential(websocket.token)
            let voice = try voiceFactory()
            await voice.setEventObserver { [weak self] event in
                await self?.receiveVoiceEvent(event)
            }
            self.voice = voice
            try await voice.start(
                .init(
                    url: websocket.url, token: websocket.token, version: websocket.version,
                    deviceID: deviceID, clientID: clientID, mode: .auto, ttsMuted: sessionTTSMuted))
            presentation = .connecting
            await publishPresentation()
            await eventPublisher.publish(.init(moduleID: id, type: EventType("xiaozhi.connecting")!))
        } catch {
            presentation = .error
            await publishPresentation()
            await eventPublisher.publish(.init(moduleID: id, type: EventType("xiaozhi.connectionFailed")!))
            if isVoiceMode { scheduleReturnHome() }
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

    private func receiveVoiceEvent(_ event: XiaozhiVoiceSessionEvent) async {
        switch event {
        case .state(let voiceState):
            presentation = .init(voiceState: voiceState)
            if voiceState == .error { scheduleReturnHome() }
        case .assistantText(let text): assistantText = text
        case .completed:
            presentation = .ready
            scheduleReturnHome()
        }
        await publishPresentation()
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
        await voice?.stop()
        voice = nil
        assistantText = nil
    }
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
