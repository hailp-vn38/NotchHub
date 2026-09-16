# ADR-0019: Use official libopus for Xiaozhi streaming audio

## Status

Accepted

## Context

The Native Xiaozhi Client needs raw Opus packets for bidirectional low-latency voice streaming. AVFoundation provides macOS capture, PCM conversion, and playback, but does not provide a stable packet-level Opus contract for the Xiaozhi protocol. A large audio/network framework or an unpinned third-party Swift wrapper would widen the Module's trust, lifecycle, and upgrade surface without solving a platform gap beyond the codec itself.

## Decision

NX uses official libopus 1.6.1 behind a small internal Swift wrapper for raw Opus encode/decode. The pinned source and its checksum produce a reproducible macOS XCFramework; the wrapper is the only Module code that calls the C API. AVAudioEngine and AVAudioConverter own microphone capture, PCM conversion, and playback. URLSession owns bootstrap and WebSocket transport. Keychain Services owns credentials and identities.

## Consequences

The module has one external codec dependency with explicit provenance and license handling. It does not use AudioKit, FFmpeg, libopusenc, Alamofire, Starscream, or a third-party Swift Opus wrapper for MVP. Any future codec upgrade must update the pinned source, checksum, reproducible build, and codec compatibility tests together.
