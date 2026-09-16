@preconcurrency import AVFoundation
@preconcurrency import Foundation

/// Holds `connect` until URLSession has completed the WebSocket upgrade.
/// Sending `hello` immediately after `URLSessionWebSocketTask.resume()` races
/// the upgrade and can fail with "Socket is not connected".
actor XiaozhiWebSocketOpenGate {
    private var continuation: CheckedContinuation<Void, Error>?

    func waitUntilOpened(start: @escaping @Sendable () -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            start()
        }
    }

    func opened() {
        continuation?.resume()
        continuation = nil
    }

    func failed(_ error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

private final class XiaozhiURLSessionWebSocketDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var gates: [Int: XiaozhiWebSocketOpenGate] = [:]

    func register(_ gate: XiaozhiWebSocketOpenGate, for task: URLSessionWebSocketTask) {
        lock.lock()
        gates[task.taskIdentifier] = gate
        lock.unlock()
    }

    func removeGate(for task: URLSessionTask) -> XiaozhiWebSocketOpenGate? {
        lock.lock()
        defer { lock.unlock() }
        return gates.removeValue(forKey: task.taskIdentifier)
    }

    func urlSession(
        _: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol _: String?
    ) {
        guard let gate = removeGate(for: webSocketTask) else { return }
        Task { await gate.opened() }
    }

    func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let gate = removeGate(for: task) else { return }
        Task { await gate.failed(error ?? URLError(.networkConnectionLost)) }
    }

    func urlSession(
        _: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith _: URLSessionWebSocketTask.CloseCode,
        reason _: Data?
    ) {
        guard let gate = removeGate(for: webSocketTask) else { return }
        Task { await gate.failed(URLError(.networkConnectionLost)) }
    }
}

public final class XiaozhiURLSessionVoiceConnector: XiaozhiVoiceConnecting, @unchecked Sendable {
    private let session: URLSession
    private let delegate: XiaozhiURLSessionWebSocketDelegate

    public init(configuration: URLSessionConfiguration = .default) {
        let delegate = XiaozhiURLSessionWebSocketDelegate()
        self.delegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    public func connect(_ request: XiaozhiVoiceConnectionRequest) async throws -> any XiaozhiVoiceTransport {
        var urlRequest = URLRequest(url: request.url)
        for (field, value) in request.headers { urlRequest.setValue(value, forHTTPHeaderField: field) }
        let task = session.webSocketTask(with: urlRequest)
        let gate = XiaozhiWebSocketOpenGate()
        delegate.register(gate, for: task)
        do {
            try await gate.waitUntilOpened { task.resume() }
        } catch {
            task.cancel(with: .goingAway, reason: nil)
            throw error
        }
        return XiaozhiURLSessionVoiceTransport(task: task)
    }
}

public actor XiaozhiURLSessionVoiceTransport: XiaozhiVoiceTransport {
    private let task: URLSessionWebSocketTask

    init(task: URLSessionWebSocketTask) { self.task = task }

    public func send(_ message: XiaozhiVoiceTransportMessage) async throws {
        switch message {
        case .text(let text): try await task.send(.string(text))
        case .binary(let data): try await task.send(.data(data))
        }
    }

    public func nextMessage() async throws -> XiaozhiVoiceTransportMessage {
        switch try await task.receive() {
        case .string(let text): .text(text)
        case .data(let data): .binary(data)
        @unknown default: throw URLError(.cannotParseResponse)
        }
    }

    public func disconnect() async { task.cancel(with: .goingAway, reason: nil) }
}

/// A diagnostic test sends its own bounded silence frame and never opens the microphone.
public actor XiaozhiSilentAudioCapture: XiaozhiAudioCapturing {
    public init() {}
    public func start(_: @escaping @Sendable (Data) -> Void) async throws {}
    public func stop() async {}
}

public actor XiaozhiAVAudioCapture: XiaozhiAudioCapturing {
    private let engine = AVAudioEngine()
    private var isRunning = false

    public init() {}

    public func start(_ onPCM: @escaping @Sendable (Data) -> Void) async throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let source = input.outputFormat(forBus: 0)
        guard
            let target = AVAudioFormat(
                commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true),
            let converter = AVAudioConverter(from: source, to: target)
        else { throw XiaozhiVoiceSessionError.audioFrame }
        input.installTap(onBus: 0, bufferSize: 1_024, format: nil) { buffer, _ in
            let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: 960)!
            var supplied = false
            var error: NSError?
            converter.convert(to: output, error: &error) { _, status in
                if supplied {
                    status.pointee = .noDataNow
                    return nil
                }
                supplied = true
                status.pointee = .haveData
                return buffer
            }
            guard error == nil, output.frameLength == 960, let samples = output.int16ChannelData?[0] else { return }
            onPCM(Data(bytes: samples, count: 1_920))
        }
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    public func stop() async {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }
}

public actor XiaozhiAVAudioPlayback: XiaozhiAudioPlaying {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var attached = false
    private var pendingBuffers = 0
    private var generation = 0
    private var drainedObserver: (@Sendable () async -> Void)?

    public init() {}

    public func enqueue(_ pcm: Data, sampleRate: Int, channels: Int) async throws {
        guard channels == 1, pcm.count.isMultiple(of: MemoryLayout<Int16>.size),
            let format = AVAudioFormat(
                commonFormat: .pcmFormatInt16, sampleRate: Double(sampleRate), channels: 1, interleaved: true)
        else { throw XiaozhiVoiceSessionError.audioFrame }
        if !attached {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.prepare()
            try engine.start()
            attached = true
        }
        let frames = AVAudioFrameCount(pcm.count / MemoryLayout<Int16>.size)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw XiaozhiVoiceSessionError.audioFrame
        }
        buffer.frameLength = frames
        pcm.withUnsafeBytes { source in
            buffer.int16ChannelData?[0].update(from: source.bindMemory(to: Int16.self).baseAddress!, count: Int(frames))
        }
        pendingBuffers += 1
        let callbackGeneration = generation
        // macOS 14 exposes only this completion API; it is the local player
        // queue-drain boundary used before the bounded return-to-home delay.
        player.scheduleBuffer(buffer) { [weak self] in
            Task { await self?.bufferDidDrain(generation: callbackGeneration) }
        }
        if !player.isPlaying { player.play() }
    }

    public func setDrainedObserver(_ observer: @escaping @Sendable () async -> Void) {
        drainedObserver = observer
    }

    public func stop() async {
        player.stop()
        generation &+= 1
        pendingBuffers = 0
        if attached {
            engine.stop()
            engine.detach(player)
            attached = false
        }
    }

    private func bufferDidDrain(generation: Int) async {
        guard generation == self.generation else { return }
        pendingBuffers = max(0, pendingBuffers - 1)
        if pendingBuffers == 0 { await drainedObserver?() }
    }
}
