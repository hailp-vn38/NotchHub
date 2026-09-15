import Foundation

public struct ActionID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init?(_ rawValue: String) {
        guard Self.isValid(rawValue), !rawValue.hasPrefix("shell.") else { return nil }
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        self.init(rawValue)
    }

    private static func isValid(_ value: String) -> Bool {
        !value.isEmpty
            && value.split(separator: ".", omittingEmptySubsequences: false).allSatisfy {
                !$0.isEmpty
                    && $0.utf8.enumerated().allSatisfy { index, byte in
                        byte.isASCIILetter || (index > 0 && byte.isNumber)
                    }
            }
    }
}

public struct ModuleID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init?(_ rawValue: String) {
        guard Identifier.isLowercaseDotSeparated(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        self.init(rawValue)
    }
}

public struct Capability: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init?(_ rawValue: String) {
        guard Identifier.isLowercaseDotSeparated(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        self.init(rawValue)
    }
}

public struct EventType: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init?(_ rawValue: String) {
        guard Identifier.isLowercaseDotSeparated(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        self.init(rawValue)
    }
}

public enum SurfaceState: String, Codable, CaseIterable, Sendable {
    case hidden
    case collapsed
    case compact
    case expanded
    case suppressed
    case recovering
}

public enum NotchDomainError: Error, Equatable, Sendable {
    case invalidEventVersion(Int)
    case invalidEventSource(String)
    case invalidEventType(String)
}

public enum EventPriority: String, Codable, Sendable {
    case low
    case normal
    case high
    case critical
}

public struct EventEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public let id: UUID
    public let version: Int
    public let source: String
    public let type: String
    public let timestamp: Date
    public let correlationID: UUID?
    public let sequence: UInt64?
    public let priority: EventPriority
    public let payload: Payload

    private enum CodingKeys: String, CodingKey {
        case id
        case version
        case source
        case type
        case timestamp
        case correlationID
        case sequence
        case priority
        case payload
    }

    public init(
        id: UUID = UUID(),
        version: Int,
        source: String,
        type: String,
        timestamp: Date,
        correlationID: UUID? = nil,
        sequence: UInt64? = nil,
        priority: EventPriority = .normal,
        payload: Payload
    ) throws {
        guard version > 0 else { throw NotchDomainError.invalidEventVersion(version) }
        guard Identifier.isLowercaseDotSeparated(source) else {
            throw NotchDomainError.invalidEventSource(source)
        }
        guard EventType(type) != nil else { throw NotchDomainError.invalidEventType(type) }

        self.id = id
        self.version = version
        self.source = source
        self.type = type
        self.timestamp = timestamp
        self.correlationID = correlationID
        self.sequence = sequence
        self.priority = priority
        self.payload = payload
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            try self.init(
                id: container.decode(UUID.self, forKey: .id),
                version: container.decode(Int.self, forKey: .version),
                source: container.decode(String.self, forKey: .source),
                type: container.decode(String.self, forKey: .type),
                timestamp: Date(
                    container.decode(String.self, forKey: .timestamp),
                    strategy: .iso8601
                ),
                correlationID: container.decodeIfPresent(UUID.self, forKey: .correlationID),
                sequence: container.decodeIfPresent(UInt64.self, forKey: .sequence),
                priority: container.decodeIfPresent(EventPriority.self, forKey: .priority) ?? .normal,
                payload: container.decode(Payload.self, forKey: .payload)
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: "Invalid Event envelope: \(error.localizedDescription)"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(version, forKey: .version)
        try container.encode(source, forKey: .source)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp.ISO8601Format(), forKey: .timestamp)
        try container.encodeIfPresent(correlationID, forKey: .correlationID)
        try container.encodeIfPresent(sequence, forKey: .sequence)
        try container.encode(priority, forKey: .priority)
        try container.encode(payload, forKey: .payload)
    }
}

public struct ActionDefinition: Codable, Identifiable, Sendable {
    public let id: ActionID
    public let title: String

    public init(id: ActionID, title: String) {
        self.id = id
        self.title = title
    }
}

public enum ShortcutModifier: String, CaseIterable, Codable, Hashable, Sendable {
    case command
    case option
    case control
    case shift
}

public struct ShortcutBinding: Codable, Equatable, Sendable {
    public let actionID: ActionID
    public let key: String
    public let modifiers: Set<ShortcutModifier>
    public let isEnabled: Bool

    public init(
        actionID: ActionID,
        key: String,
        modifiers: Set<ShortcutModifier>,
        isEnabled: Bool = true
    ) {
        self.actionID = actionID
        self.key = key.lowercased()
        self.modifiers = modifiers
        self.isEnabled = isEnabled
    }

    public var isValid: Bool {
        key.unicodeScalars.count == 1
            && !key.unicodeScalars.allSatisfy(\.properties.isWhitespace)
            && !modifiers.isEmpty
    }
}

public enum SurfaceSlot: String, Codable, CaseIterable, Hashable, Sendable {
    case indicator
    case compactStatus
}

public struct ModuleRuntimePolicy: Codable, Equatable, Sendable {
    public let maximumEventRatePerMinute: Int

    public init(maximumEventRatePerMinute: Int = 60) {
        self.maximumEventRatePerMinute = maximumEventRatePerMinute
    }
}

public struct ModuleMetadata: Codable, Equatable, Sendable {
    public let displayName: String
    public let version: String
    public let supportedSurfaceSlots: Set<SurfaceSlot>
    public let requiredCapabilities: Set<Capability>
    public let optionalCapabilities: Set<Capability>
    public let runtimePolicy: ModuleRuntimePolicy

    public init(
        displayName: String,
        version: String = "1.0.0",
        supportedSurfaceSlots: Set<SurfaceSlot> = [],
        requiredCapabilities: Set<Capability> = [],
        optionalCapabilities: Set<Capability> = [],
        runtimePolicy: ModuleRuntimePolicy = .init()
    ) {
        self.displayName = displayName
        self.version = version
        self.supportedSurfaceSlots = supportedSurfaceSlots
        self.requiredCapabilities = requiredCapabilities
        self.optionalCapabilities = optionalCapabilities
        self.runtimePolicy = runtimePolicy
    }

    /// Compatibility projection; new callers distinguish required and optional capabilities.
    public var capabilities: Set<Capability> { requiredCapabilities.union(optionalCapabilities) }
}

public enum ModuleLifecycleState: String, Codable, Equatable, Sendable {
    case registered
    case starting
    case running
    case suspended
    case stopping
    case stopped
    case failed
}

public struct ModuleHealth: Codable, Equatable, Sendable, Identifiable {
    public let id: ModuleID
    public let state: ModuleLifecycleState
    public let isEnabled: Bool
    public let lastStartedAt: Date?
    public let lastError: String?
    public let restartCount: Int

    public init(
        id: ModuleID,
        state: ModuleLifecycleState = .registered,
        isEnabled: Bool,
        lastStartedAt: Date? = nil,
        lastError: String? = nil,
        restartCount: Int = 0
    ) {
        self.id = id
        self.state = state
        self.isEnabled = isEnabled
        self.lastStartedAt = lastStartedAt
        self.lastError = lastError
        self.restartCount = restartCount
    }
}

public struct SurfaceContributionDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let moduleID: ModuleID
    public let slot: SurfaceSlot
    public let text: String

    public var id: String { "\(moduleID.rawValue).\(slot.rawValue)" }

    public init(moduleID: ModuleID, slot: SurfaceSlot, text: String) {
        self.moduleID = moduleID
        self.slot = slot
        self.text = text
    }
}

public struct ModuleEvent: Codable, Equatable, Sendable {
    public let moduleID: ModuleID
    public let type: EventType

    public init(moduleID: ModuleID, type: EventType) {
        self.moduleID = moduleID
        self.type = type
    }
}

private enum Identifier {
    static func isLowercaseDotSeparated(_ value: String) -> Bool {
        !value.isEmpty
            && value.split(separator: ".", omittingEmptySubsequences: false).allSatisfy {
                !$0.isEmpty
                    && $0.utf8.enumerated().allSatisfy { index, byte in
                        byte.isASCIILowercase || (index > 0 && byte.isNumber)
                    }
            }
    }
}

extension UInt8 {
    fileprivate var isASCIILetter: Bool {
        isASCIILowercase || (65...90).contains(self)
    }

    fileprivate var isASCIILowercase: Bool {
        (97...122).contains(self)
    }

    fileprivate var isNumber: Bool {
        (48...57).contains(self)
    }
}
