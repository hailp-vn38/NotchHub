import Foundation
import OpusBridge

public enum XiaozhiOpusCodecError: Error, Equatable, Sendable { case encoderUnavailable, decoderUnavailable, encodeFailed, decodeFailed }

/// Thin Swift owner for the pinned official libopus C boundary.
public final class XiaozhiOpusCodec: XiaozhiOpusCoding, @unchecked Sendable {
    private let encoder: OpaquePointer
    private var decoders: [Int: OpaquePointer] = [:]
    private let lock = NSLock()

    public init() throws {
        guard let encoder = opus_bridge_encoder_create() else { throw XiaozhiOpusCodecError.encoderUnavailable }
        self.encoder = encoder
    }

    deinit {
        opus_bridge_encoder_destroy(encoder)
        for decoder in decoders.values { opus_bridge_decoder_destroy(decoder) }
    }

    public func encode(_ pcm16kMono: Data) throws -> Data {
        guard pcm16kMono.count == 1_920 else { throw XiaozhiOpusCodecError.encodeFailed }
        lock.lock(); defer { lock.unlock() }
        var packet = Data(count: 4_000)
        let count = pcm16kMono.withUnsafeBytes { pcm in
            packet.withUnsafeMutableBytes { output in
                opus_bridge_encode(encoder, pcm.bindMemory(to: Int16.self).baseAddress, 960,
                                   output.bindMemory(to: UInt8.self).baseAddress, 4_000)
            }
        }
        guard count > 0 else { throw XiaozhiOpusCodecError.encodeFailed }
        packet.removeSubrange(Int(count)..<packet.count)
        return packet
    }

    public func decode(_ packet: Data, sampleRate: Int, channels: Int) throws -> Data {
        guard channels == 1, sampleRate > 0 else { throw XiaozhiOpusCodecError.decodeFailed }
        lock.lock(); defer { lock.unlock() }
        let decoder = try decoder(for: sampleRate)
        var pcm = Data(count: sampleRate / 10 * MemoryLayout<Int16>.size)
        let samples = packet.withUnsafeBytes { input in
            pcm.withUnsafeMutableBytes { output in
                opus_bridge_decode(decoder, input.bindMemory(to: UInt8.self).baseAddress, Int32(packet.count),
                                   output.bindMemory(to: Int16.self).baseAddress, Int32(sampleRate / 10))
            }
        }
        guard samples >= 0 else { throw XiaozhiOpusCodecError.decodeFailed }
        pcm.removeSubrange(Int(samples) * MemoryLayout<Int16>.size..<pcm.count)
        return pcm
    }

    private func decoder(for sampleRate: Int) throws -> OpaquePointer {
        if let decoder = decoders[sampleRate] { return decoder }
        guard let decoder = opus_bridge_decoder_create(Int32(sampleRate), 1) else { throw XiaozhiOpusCodecError.decoderUnavailable }
        decoders[sampleRate] = decoder
        return decoder
    }
}
