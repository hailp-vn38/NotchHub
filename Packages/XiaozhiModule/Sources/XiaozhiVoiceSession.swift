import Foundation
import NotchCore
import OSLog

public enum XiaozhiVoiceTransportMessage: Sendable {
    case text(String)
    case binary(Data)
}

public struct XiaozhiVoiceConnectionRequest: Sendable {
    public let url: URL
    public let headers: [String: String]

    public init(url: URL, headers: [String: String]) {
        self.url = url
        self.headers = headers
    }
}

public protocol XiaozhiVoiceTransport: Sendable {
    func send(_ message: XiaozhiVoiceTransportMessage) async throws
    func nextMessage() async throws -> XiaozhiVoiceTransportMessage
    func disconnect() async
}

public protocol XiaozhiVoiceConnecting: Sendable {
    func connect(_ request: XiaozhiVoiceConnectionRequest) async throws -> any XiaozhiVoiceTransport
}

public protocol XiaozhiAudioCapturing: Sendable {
    func start(_ onPCM: @escaping @Sendable (Data) -> Void) async throws
    func stop() async
}

public protocol XiaozhiAudioPlaying: Sendable {
    func enqueue(_ pcm: Data, sampleRate: Int, channels: Int) async throws
    func setDrainedObserver(_ observer: @escaping @Sendable () async -> Void) async
    func stop() async
}

/// The sole codec boundary. Production uses the official libopus wrapper;
/// transport and presentation never handle raw PCM or codec state.
public protocol XiaozhiOpusCoding: Sendable {
    func encode(_ pcm16kMono: Data) throws -> Data
    func decode(_ packet: Data, sampleRate: Int, channels: Int) throws -> Data
}

public enum XiaozhiVoiceState: String, Equatable, Sendable {
    case ready, connecting, handshaking, idle, listening, thinking, speaking, error
}

public struct XiaozhiVoiceSessionSnapshot: Equatable, Sendable, CustomStringConvertible {
    public let voiceState: XiaozhiVoiceState
    public let sessionID: String?
    public let inputSampleRate: Int
    public let outputSampleRate: Int?
    public let frameDurationMS: Int
    public let droppedUplinkFrames: Int
    public let droppedDownlinkFrames: Int
    public let lastError: String?

    public var description: String {
        "XiaozhiVoiceSessionSnapshot(state: \(voiceState.rawValue), session: \(sessionID == nil ? "none" : "active"))"
    }
}

public struct XiaozhiVoiceSessionConfiguration: Sendable {
    public let url: URL
    public let token: String
    public let version: Int
    public let deviceID: String
    public let clientID: String
    public let mode: XiaozhiConversationMode
    public let ttsMuted: Bool

    public init(
        url: URL,
        token: String,
        version: Int,
        deviceID: String,
        clientID: String,
        mode: XiaozhiConversationMode,
        ttsMuted: Bool = false
    ) {
        self.url = url
        self.token = token
        self.version = version
        self.deviceID = deviceID
        self.clientID = clientID
        self.mode = mode
        self.ttsMuted = ttsMuted
    }
}

/// Normalized session events. They deliberately exclude the upstream payload,
/// audio frames, identifiers, and credentials.
public enum XiaozhiVoiceSessionEvent: Equatable, Sendable {
    case state(XiaozhiVoiceState)
    case assistantText(String)
    case completed
}

public enum XiaozhiVoiceSessionError: Error, Equatable, Sendable {
    case malformedMessage, invalidHello, noSession, pushToTalkOnly, audioFrame
}

/// Owns one authenticated voice session. Its snapshot is normalized and
/// intentionally excludes credentials, headers, raw packets, and transcripts.
public actor XiaozhiVoiceSession {
    private static let uplinkFrameLimit = 40  // 40 × 60 ms = 2400 ms.
    private static let downlinkFrameLimit = 20  // 20 × 60 ms = 1200 ms.
    private static let logger = Logger(subsystem: "NotchHub", category: "xiaozhi.websocket")

    private let connector: any XiaozhiVoiceConnecting
    private let capture: any XiaozhiAudioCapturing
    private let playback: any XiaozhiAudioPlaying
    private let codec: any XiaozhiOpusCoding
    private var transport: (any XiaozhiVoiceTransport)?
    private var receiveTask: Task<Void, Never>?
    private var downlinkTask: Task<Void, Never>?
    private var configuration: XiaozhiVoiceSessionConfiguration?
    private var state: XiaozhiVoiceState = .ready
    private var sessionID: String?
    private var outputSampleRate: Int?
    private var outputChannels = 1
    private var uplink: [Data] = []
    private var downlink: [Data] = []
    private var droppedUplinkFrames = 0
    private var droppedDownlinkFrames = 0
    private var lastError: String?
    private var eventObserver: (@Sendable (XiaozhiVoiceSessionEvent) async -> Void)?
    private var didReceiveTTSStop = false
    private var isPlaybackDrained = true

    public init(
        connector: any XiaozhiVoiceConnecting, capture: any XiaozhiAudioCapturing, playback: any XiaozhiAudioPlaying,
        codec: any XiaozhiOpusCoding
    ) {
        self.connector = connector
        self.capture = capture
        self.playback = playback
        self.codec = codec
    }

    /// Observes normalized state, bounded assistant text, and completion only.
    public func setEventObserver(_ observer: @escaping @Sendable (XiaozhiVoiceSessionEvent) async -> Void) {
        eventObserver = observer
    }

    public func start(_ configuration: XiaozhiVoiceSessionConfiguration) async throws {
        await resetResources()
        self.configuration = configuration
        didReceiveTTSStop = false
        isPlaybackDrained = true
        await playback.setDrainedObserver { [weak self] in await self?.playbackDidDrain() }
        state = .connecting
        let authorization =
            configuration.token.lowercased().hasPrefix("bearer ")
            ? configuration.token : "Bearer \(configuration.token)"
        let request = XiaozhiVoiceConnectionRequest(
            url: configuration.url,
            headers: [
                "Authorization": authorization,
                "Protocol-Version": String(configuration.version),
                "Device-Id": configuration.deviceID,
                "Client-Id": configuration.clientID,
            ])
        transport = try await connector.connect(request)
        state = .handshaking
        try await sendJSON([
            "type": "hello", "version": configuration.version, "features": [:], "transport": "websocket",
            "audio_params": ["format": "opus", "sample_rate": 16_000, "channels": 1, "frame_duration": 60],
        ])
        let transport = try requireTransport()
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await self?.receive(transport.nextMessage()) } catch {
                    await self?.failProtocol()
                    await self?.emit(.state(.error))
                    return
                }
            }
        }
    }

    public func receive(_ message: XiaozhiVoiceTransportMessage) async throws {
        do {
            switch message {
            case .text(let text):
                Self.logIncomingText(text)
                try await receiveText(text)
            case .binary(let packet):
                Self.logger.debug("received WebSocket binary packet bytes=\(packet.count, privacy: .public)")
                try await receiveAudio(packet)
            }
            await emit(.state(state))
        } catch {
            await failProtocol()
            await emit(.state(state))
            if let error = error as? XiaozhiVoiceSessionError { throw error }
            throw XiaozhiVoiceSessionError.malformedMessage
        }
    }

    public func beginPushToTalk() async throws {
        guard configuration?.mode == .pushToTalk else { throw XiaozhiVoiceSessionError.pushToTalkOnly }
        guard let sessionID else { throw XiaozhiVoiceSessionError.noSession }
        try await sendJSON(["session_id": sessionID, "type": "listen", "state": "start", "mode": "manual"])
        try await beginCapture()
        state = .listening
    }

    public func endPushToTalk() async throws {
        guard configuration?.mode == .pushToTalk else { throw XiaozhiVoiceSessionError.pushToTalkOnly }
        guard let sessionID else { throw XiaozhiVoiceSessionError.noSession }
        await capture.stop()
        try await flushUplink()
        try await sendJSON(["session_id": sessionID, "type": "listen", "state": "stop"])
        state = .thinking
    }

    public func enqueueMicrophonePCM(_ pcm: Data) throws {
        guard pcm.count == 1_920 else { throw XiaozhiVoiceSessionError.audioFrame }
        if uplink.count == Self.uplinkFrameLimit {
            uplink.removeFirst()
            droppedUplinkFrames += 1
        }
        uplink.append(pcm)
    }

    public func flushUplink() async throws {
        while !uplink.isEmpty {
            let pcm = uplink.removeFirst()
            try await transport?.send(.binary(try codec.encode(pcm)))
        }
    }

    public func snapshot() -> XiaozhiVoiceSessionSnapshot {
        .init(
            voiceState: state, sessionID: sessionID, inputSampleRate: 16_000,
            outputSampleRate: outputSampleRate, frameDurationMS: 60,
            droppedUplinkFrames: droppedUplinkFrames, droppedDownlinkFrames: droppedDownlinkFrames,
            lastError: lastError)
    }

    public func stop() async {
        await resetResources()
        configuration = nil
        state = .ready
    }

    public func abort() async throws {
        guard let sessionID else { throw XiaozhiVoiceSessionError.noSession }
        await playback.stop()
        await capture.stop()
        uplink.removeAll()
        downlink.removeAll()
        try await sendJSON(["session_id": sessionID, "type": "abort"])
        state = configuration?.mode == .auto ? .listening : .idle
    }

    public func reconnect() async throws {
        guard let configuration else { throw XiaozhiVoiceSessionError.noSession }
        try await start(configuration)
    }

    private func receiveText(_ text: String) async throws {
        guard let data = text.data(using: .utf8),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = object["type"] as? String
        else { throw XiaozhiVoiceSessionError.malformedMessage }
        switch type {
        case "hello":
            guard let id = object["session_id"] as? String,
                let audio = object["audio_params"] as? [String: Any],
                audio["format"] as? String == "opus",
                let sampleRate = audio["sample_rate"] as? Int,
                let channels = audio["channels"] as? Int,
                sampleRate > 0, channels == 1
            else { throw XiaozhiVoiceSessionError.invalidHello }
            sessionID = id
            outputSampleRate = sampleRate
            outputChannels = channels
            state = .idle
            if configuration?.mode == .auto {
                try await startAutoListening()
            }
        case "stt": state = .thinking
        case "tts":
            switch object["state"] as? String {
            case "start":
                state = .speaking
                if let text = object["text"] as? String, !text.isEmpty {
                    await emit(.assistantText(String(text.prefix(280))))
                }
            case "stop":
                didReceiveTTSStop = true
                await capture.stop()
                await publishCompletionIfReady()
            default: throw XiaozhiVoiceSessionError.malformedMessage
            }
        default: throw XiaozhiVoiceSessionError.malformedMessage
        }
    }

    /// Logs protocol metadata only. Raw JSON can contain conversation text,
    /// session IDs, or credentials and must not leave the session boundary.
    private static func logIncomingText(_ text: String) {
        guard
            let data = text.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            logger.debug("received malformed WebSocket text bytes=\(text.utf8.count, privacy: .public)")
            return
        }
        let type = object["type"] as? String ?? "missing"
        let state = object["state"] as? String ?? "none"
        logger.debug(
            "received WebSocket text type=\(type, privacy: .public) state=\(state, privacy: .public) bytes=\(text.utf8.count, privacy: .public)")
    }

    private func receiveAudio(_ packet: Data) async throws {
        guard outputSampleRate != nil else { throw XiaozhiVoiceSessionError.noSession }
        guard configuration?.ttsMuted != true else { return }
        isPlaybackDrained = false
        if downlink.count == Self.downlinkFrameLimit {
            downlink.removeFirst()
            droppedDownlinkFrames += 1
        }
        downlink.append(packet)
        if downlinkTask == nil {
            downlinkTask = Task { [weak self] in await self?.drainDownlink() }
        }
    }

    private func startAutoListening() async throws {
        guard let sessionID else { throw XiaozhiVoiceSessionError.noSession }
        try await sendJSON(["session_id": sessionID, "type": "listen", "state": "start", "mode": "auto"])
        try await beginCapture()
        state = .listening
    }

    private func beginCapture() async throws {
        try await capture.start { [weak self] pcm in
            Task {
                try? await self?.enqueueMicrophonePCM(pcm)
                try? await self?.flushUplink()
            }
        }
    }

    private func sendJSON(_ object: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try await transport?.send(.text(String(decoding: data, as: UTF8.self)))
    }

    private func failProtocol() async {
        await playback.stop()
        await capture.stop()
        sessionID = nil
        uplink.removeAll()
        downlink.removeAll()
        state = .error
        lastError = "Protocol error."
    }

    private func resetResources() async {
        receiveTask?.cancel()
        receiveTask = nil
        downlinkTask?.cancel()
        downlinkTask = nil
        await playback.stop()
        await capture.stop()
        await transport?.disconnect()
        transport = nil
        sessionID = nil
        uplink.removeAll()
        downlink.removeAll()
        outputSampleRate = nil
        outputChannels = 1
        didReceiveTTSStop = false
        isPlaybackDrained = true
    }

    private func requireTransport() throws -> any XiaozhiVoiceTransport {
        guard let transport else { throw XiaozhiVoiceSessionError.noSession }
        return transport
    }

    private func drainDownlink() async {
        while !Task.isCancelled, let sampleRate = outputSampleRate, !downlink.isEmpty {
            let packet = downlink.removeFirst()
            do {
                try await playback.enqueue(
                    try codec.decode(packet, sampleRate: sampleRate, channels: outputChannels), sampleRate: sampleRate,
                    channels: outputChannels)
            } catch {
                await failProtocol()
                return
            }
        }
        downlinkTask = nil
    }

    private func playbackDidDrain() async {
        isPlaybackDrained = true
        await publishCompletionIfReady()
    }

    private func publishCompletionIfReady() async {
        guard didReceiveTTSStop, configuration?.ttsMuted == true || isPlaybackDrained else { return }
        didReceiveTTSStop = false
        state = .idle
        await emit(.completed)
    }

    private func emit(_ event: XiaozhiVoiceSessionEvent) async { await eventObserver?(event) }
}
