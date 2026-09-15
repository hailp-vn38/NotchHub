import Foundation

public enum IPCSource: Equatable, Sendable {
    case notchctl
    case debugInjector
    case unknown(String)
}

public struct IPCSystemTestMessage: Sendable {
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

public enum IPCOperation: Sendable {
    case health
    case status
    case event(IPCSystemTestMessage)
    case openSettings
}

public struct IPCRequest: Sendable {
    public let id: UUID
    public let token: String
    public let source: IPCSource
    public let operation: IPCOperation

    public init(id: UUID, token: String, source: IPCSource, operation: IPCOperation) {
        self.id = id
        self.token = token
        self.source = source
        self.operation = operation
    }
}

public enum IPCResponseStatus: Equatable, Sendable {
    case accepted
    case duplicate
    case unauthorized
    case forbidden
    case invalid
    case rateLimited
}

public struct IPCResponse: Equatable, Sendable {
    public let status: IPCResponseStatus
    public init(status: IPCResponseStatus) { self.status = status }
}

public protocol IPCPresenting: Actor {
    func presentCompact(title: String, message: String)
}

public actor NotchIPCService {
    public static let maximumTitleBytes = 160
    public static let maximumMessageBytes = 4 * 1024
    public static let maximumEventsPerMinute = 10
    private static let duplicateWindow: TimeInterval = 5 * 60

    private var token: String
    private let presentation: (any IPCPresenting)?
    private let openSettings: (@MainActor @Sendable () -> Void)?
    private var recentIDs: [UUID: Date] = [:]
    private var eventTimes: [Date] = []

    public init(
        token: String,
        presentation: (any IPCPresenting)? = nil,
        openSettings: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.token = token
        self.presentation = presentation
        self.openSettings = openSettings
    }

    public func rotate(token: String) { self.token = token }

    public func handle(_ request: IPCRequest, now: Date = .now) async -> IPCResponse {
        guard request.token == token else { return .init(status: .unauthorized) }
        guard isAllowed(request.source) else { return .init(status: .forbidden) }
        expireEntries(before: now.addingTimeInterval(-Self.duplicateWindow))
        if recentIDs[request.id] != nil { return .init(status: .duplicate) }

        switch request.operation {
        case .health, .status:
            recentIDs[request.id] = now
            return .init(status: .accepted)
        case .openSettings:
            recentIDs[request.id] = now
            if let openSettings { await openSettings() }
            return .init(status: .accepted)
        case .event(let event):
            guard event.title.utf8.count <= Self.maximumTitleBytes,
                  event.message.utf8.count <= Self.maximumMessageBytes
            else { return .init(status: .invalid) }
            eventTimes.removeAll { $0 < now.addingTimeInterval(-60) }
            guard eventTimes.count < Self.maximumEventsPerMinute else { return .init(status: .rateLimited) }
            eventTimes.append(now)
            recentIDs[request.id] = now
            if let presentation { await presentation.presentCompact(title: event.title, message: event.message) }
            return .init(status: .accepted)
        }
    }

    private func isAllowed(_ source: IPCSource) -> Bool {
        switch source {
        case .notchctl: true
        case .debugInjector: false
        case .unknown: false
        }
    }

    private func expireEntries(before date: Date) {
        recentIDs = recentIDs.filter { $0.value >= date }
    }
}
