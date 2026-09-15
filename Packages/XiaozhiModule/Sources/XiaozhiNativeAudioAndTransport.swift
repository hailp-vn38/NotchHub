@preconcurrency import AVFoundation
@preconcurrency import Foundation

public struct XiaozhiURLSessionVoiceConnector: XiaozhiVoiceConnecting {
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }

    public func connect(_ request: XiaozhiVoiceConnectionRequest) async throws -> any XiaozhiVoiceTransport {
        var urlRequest = URLRequest(url: request.url)
        for (field, value) in request.headers { urlRequest.setValue(value, forHTTPHeaderField: field) }
        let task = session.webSocketTask(with: urlRequest)
        task.resume()
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

public actor XiaozhiAVAudioCapture: XiaozhiAudioCapturing {
    private let engine = AVAudioEngine()
    private var isRunning = false

    public init() {}

    public func start(_ onPCM: @escaping @Sendable (Data) -> Void) async throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let source = input.outputFormat(forBus: 0)
        guard let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: source, to: target)
        else { throw XiaozhiVoiceSessionError.audioFrame }
        input.installTap(onBus: 0, bufferSize: 1_024, format: nil) { buffer, _ in
            let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: 960)!
            var supplied = false
            var error: NSError?
            converter.convert(to: output, error: &error) { _, status in
                if supplied { status.pointee = .noDataNow; return nil }
                supplied = true; status.pointee = .haveData; return buffer
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

    public init() {}

    public func enqueue(_ pcm: Data, sampleRate: Int, channels: Int) async throws {
        guard channels == 1, pcm.count.isMultiple(of: MemoryLayout<Int16>.size),
              let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Double(sampleRate), channels: 1, interleaved: true)
        else { throw XiaozhiVoiceSessionError.audioFrame }
        if !attached {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.prepare()
            try engine.start()
            attached = true
        }
        let frames = AVAudioFrameCount(pcm.count / MemoryLayout<Int16>.size)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { throw XiaozhiVoiceSessionError.audioFrame }
        buffer.frameLength = frames
        pcm.withUnsafeBytes { source in
            buffer.int16ChannelData?[0].update(from: source.bindMemory(to: Int16.self).baseAddress!, count: Int(frames))
        }
        await player.scheduleBuffer(buffer)
        if !player.isPlaying { player.play() }
    }

    public func stop() async {
        player.stop()
        if attached { engine.stop(); engine.detach(player); attached = false }
    }
}
