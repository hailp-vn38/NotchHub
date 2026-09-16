# ADR-0018: Use a native Xiaozhi client with direct cloud connection

## Status

Accepted

## Context

The earlier roadmap described a display-only Xiaozhi relay phase (M1) followed by a separate native-voice phase (M5). The product instead needs one macOS Module that owns the Xiaozhi bootstrap, authenticated WebSocket session, microphone input, TTS playback, and normalized presentation state without coupling the Notch surface to the upstream protocol.

## Decision

NotchHub will implement Xiaozhi as the single static native macOS Module milestone `NX`, replacing M1 and M5. It connects directly to the default Xiaozhi Cloud bootstrap service. Custom bootstrap URLs are an advanced, non-compatibility-guaranteed option. The module may prepare to `ready` at launch, but it opens neither a voice WebSocket nor the microphone until a user invokes a conversation Action. Its schema and Settings application-scene UI are module-owned; its non-secret values, including editable identity, are persisted as a versioned, namespaced entry of the shared Settings store. Credentials are session-only and never persisted. The initial scope excludes MCP and transcript persistence. Expanded Notch content exposes only immediate conversation controls and status; durable configuration and diagnostics remain application scenes.

## Consequences

Integration acceptance is measured first against the default cloud backend. The platform needs a microphone capability in the existing central Permission Coordinator before voice work can ship. No Xiaozhi raw protocol, secret, or high-rate audio frame reaches the Notch surface or shared EventBus.
