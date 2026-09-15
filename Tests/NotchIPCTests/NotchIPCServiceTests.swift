import Foundation
import NotchDomain
import NotchIPC
import Testing

@Test("IPC accepts one authorized system test message and deduplicates its retry")
func acceptsAndDeduplicatesTestMessage() async throws {
    let recorder = IPCRecordingPresentation()
    let service = NotchIPCService(
        token: "test-token",
        presentation: recorder
    )
    let id = UUID()
    let request = IPCRequest(
        id: id,
        token: "test-token",
        source: .notchctl,
        operation: .event(.init(title: "Foundation", message: "IPC works"))
    )

    #expect(await service.handle(request).status == .accepted)
    #expect(await service.handle(request).status == .duplicate)
    #expect(await recorder.messages == ["Foundation: IPC works"])
}

@Test("IPC rejects an unknown source before it can publish an event")
func rejectsUnknownSource() async throws {
    let service = NotchIPCService(token: "test-token")
    let request = IPCRequest(
        id: UUID(), token: "test-token", source: .unknown("relay"),
        operation: .event(.init(title: "Foundation", message: "IPC works"))
    )

    #expect(await service.handle(request).status == .forbidden)
}

@Test("IPC rejects oversized and rate-limited messages without presenting them")
func rejectsBoundedMessageInput() async throws {
    let recorder = IPCRecordingPresentation()
    let service = NotchIPCService(token: "test-token", presentation: recorder)
    let oversized = IPCRequest(
        id: UUID(), token: "test-token", source: .notchctl,
        operation: .event(.init(title: String(repeating: "x", count: 161), message: "ok"))
    )
    #expect(await service.handle(oversized).status == .invalid)

    let now = Date(timeIntervalSince1970: 0)
    for _ in 0..<NotchIPCService.maximumEventsPerMinute {
        #expect(await service.handle(.init(
            id: UUID(), token: "test-token", source: .notchctl,
            operation: .event(.init(title: "ok", message: "ok"))
        ), now: now).status == .accepted)
    }
    #expect(await service.handle(.init(
        id: UUID(), token: "test-token", source: .notchctl,
        operation: .event(.init(title: "ok", message: "ok"))
    ), now: now).status == .rateLimited)
}

private actor IPCRecordingPresentation: IPCPresenting {
    var messages: [String] = []

    func presentCompact(title: String, message: String) {
        messages.append("\(title): \(message)")
    }
}
