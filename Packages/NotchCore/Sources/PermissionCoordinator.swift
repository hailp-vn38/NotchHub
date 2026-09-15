import Foundation

public enum PermissionKind: String, CaseIterable, Codable, Hashable, Sendable {
    case accessibility
    case notifications
    case microphone
    case calendar
    case reminders
    case camera
    case screenRecording
    case automation
}

public enum PermissionStatus: String, Codable, Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable
}

public enum PermissionRequestSource: String, Codable, Sendable {
    case settings
    case featureInteraction
    case onboarding
    case recovery
}

public enum PermissionFeatureID {
    public static let recoveryNotifications = "permission.recoveryNotifications"
}

/// Declares the one F5 capability that is allowed to reach a platform adapter.
/// Future phases can provide their own requirements without granting a request path here.
public struct PermissionRequirement: Equatable, Sendable {
    public let featureID: String
    public let kind: PermissionKind

    public init(featureID: String, kind: PermissionKind) {
        self.featureID = featureID
        self.kind = kind
    }
}

public struct PermissionRequestContext: Sendable {
    public let featureID: String
    public let reason: String
    public let initiatedByUser: Bool
    public let source: PermissionRequestSource
    public let explanationAcknowledged: Bool

    public init(
        featureID: String,
        reason: String,
        initiatedByUser: Bool,
        source: PermissionRequestSource,
        explanationAcknowledged: Bool
    ) {
        self.featureID = featureID
        self.reason = reason
        self.initiatedByUser = initiatedByUser
        self.source = source
        self.explanationAcknowledged = explanationAcknowledged
    }
}

public enum PermissionRequestRejection: Equatable, Sendable {
    case userInitiationRequired
    case explanationRequired
    case reasonRequired
    case unsupportedCapability
    case unknownFeature
    case requirementMismatch
    case sourceNotAllowed
    case recoveryCannotPrompt
}

public enum PermissionRequestResult: Equatable, Sendable {
    case authorized
    case denied
    case restricted
    case unavailable
    case rejected(PermissionRequestRejection)
}

public struct PermissionGuidance: Equatable, Sendable {
    public let reason: String
    public let dataImplication: String
    public let declineEffect: String
    public let nextAction: String

    public init(reason: String, dataImplication: String, declineEffect: String, nextAction: String) {
        self.reason = reason
        self.dataImplication = dataImplication
        self.declineEffect = declineEffect
        self.nextAction = nextAction
    }
}

public struct PermissionRow: Equatable, Sendable {
    public let kind: PermissionKind
    public let status: PermissionStatus
    public let guidance: PermissionGuidance

    public init(kind: PermissionKind, status: PermissionStatus, guidance: PermissionGuidance) {
        self.kind = kind
        self.status = status
        self.guidance = guidance
    }
}

public struct PermissionSnapshot: Equatable, Sendable {
    public let rows: [PermissionRow]

    public init(rows: [PermissionRow]) {
        self.rows = rows
    }

    public func row(for kind: PermissionKind) -> PermissionRow? {
        rows.first { $0.kind == kind }
    }
}

public struct PermissionAuditEvent: Equatable, Sendable {
    public let kind: PermissionKind
    public let before: PermissionStatus
    public let after: PermissionStatus
    public let featureID: String
    public let source: PermissionRequestSource
    public let explanationShown: Bool
    public let outcome: PermissionRequestResult
    public let appVersion: String
    public let timestamp: Date

    public init(
        kind: PermissionKind,
        before: PermissionStatus,
        after: PermissionStatus,
        featureID: String,
        source: PermissionRequestSource,
        explanationShown: Bool,
        outcome: PermissionRequestResult,
        appVersion: String,
        timestamp: Date = .now
    ) {
        self.kind = kind
        self.before = before
        self.after = after
        self.featureID = featureID
        self.source = source
        self.explanationShown = explanationShown
        self.outcome = outcome
        self.appVersion = appVersion
        self.timestamp = timestamp
    }
}

public protocol PermissionAuditSinking: Sendable {
    func record(_ event: PermissionAuditEvent) async
}

public protocol PermissionAdapter: Sendable {
    func status(for kind: PermissionKind) async -> PermissionStatus
    func requestAuthorization(for kind: PermissionKind) async -> PermissionStatus
    func openSystemSettings(for kind: PermissionKind) async -> Bool
}

public actor PermissionCoordinator {
    private let adapter: any PermissionAdapter
    private let auditSink: (any PermissionAuditSinking)?
    private let requirements: [PermissionRequirement]
    private let appVersion: String
    private var statuses: [PermissionKind: PermissionStatus] = [:]
    private var inFlightRequests: [PermissionKind: Task<PermissionStatus, Never>] = [:]

    public init(
        adapter: any PermissionAdapter,
        requirements: [PermissionRequirement] = [
            .init(featureID: PermissionFeatureID.recoveryNotifications, kind: .notifications)
        ],
        appVersion: String = "unknown",
        auditSink: (any PermissionAuditSinking)? = nil
    ) {
        self.adapter = adapter
        self.requirements = requirements
        self.appVersion = appVersion
        self.auditSink = auditSink
    }

    public func request(
        _ kind: PermissionKind,
        context: PermissionRequestContext
    ) async -> PermissionRequestResult {
        guard context.initiatedByUser else { return .rejected(.userInitiationRequired) }
        guard context.explanationAcknowledged else { return .rejected(.explanationRequired) }
        guard !context.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .rejected(.reasonRequired)
        }
        guard requirements.contains(where: { $0.featureID == context.featureID }) else {
            return .rejected(.unknownFeature)
        }
        guard requirements.contains(.init(featureID: context.featureID, kind: kind)) else {
            return .rejected(.requirementMismatch)
        }
        guard context.source != .recovery else { return .rejected(.recoveryCannotPrompt) }
        guard context.source == .settings else { return .rejected(.sourceNotAllowed) }
        guard kind == .notifications else { return .rejected(.unsupportedCapability) }

        let before: PermissionStatus
        if let cached = statuses[kind] {
            before = cached
        } else {
            before = await adapter.status(for: kind)
        }
        statuses[kind] = before
        guard before == .notDetermined else { return Self.result(for: before) }

        if let inFlight = inFlightRequests[kind] {
            return Self.result(for: await inFlight.value)
        }

        let adapter = self.adapter
        let request = Task { await adapter.requestAuthorization(for: kind) }
        inFlightRequests[kind] = request
        let status = await request.value
        inFlightRequests[kind] = nil
        statuses[kind] = status
        let result = Self.result(for: status)
        await auditSink?.record(
            .init(
                kind: kind,
                before: before,
                after: status,
                featureID: context.featureID,
                source: context.source,
                explanationShown: context.explanationAcknowledged,
                outcome: result,
                appVersion: appVersion
            )
        )
        return result
    }

    public func refresh() async {
        statuses[.notifications] = await adapter.status(for: .notifications)
    }

    public func openSystemSettings(for kind: PermissionKind) async -> Bool {
        guard kind == .notifications else { return false }
        return await adapter.openSystemSettings(for: kind)
    }

    public func snapshot() -> PermissionSnapshot {
        .init(rows: [
            .init(
                kind: .notifications,
                status: statuses[.notifications] ?? .notDetermined,
                guidance: Self.notificationsGuidance(for: statuses[.notifications] ?? .notDetermined)
            )
        ])
    }

    private static func result(for status: PermissionStatus) -> PermissionRequestResult {
        return switch status {
        case .authorized: .authorized
        case .denied, .notDetermined: .denied
        case .restricted: .restricted
        case .unavailable: .unavailable
        }
    }

    private static func notificationsGuidance(for status: PermissionStatus) -> PermissionGuidance {
        let reason = "Used only for concise Permission Center recovery messages."
        let dataImplication = "No transcripts, files, clipboard, audio, screen content, or tokens are used."
        return switch status {
        case .notDetermined:
            .init(
                reason: reason, dataImplication: dataImplication,
                declineEffect: "You can continue using NotchHub without recovery notifications.",
                nextAction: "Enable recovery notifications")
        case .authorized:
            .init(
                reason: reason, dataImplication: dataImplication, declineEffect: "No action is needed.",
                nextAction: "Recovery notifications are enabled")
        case .denied:
            .init(
                reason: reason, dataImplication: dataImplication,
                declineEffect: "NotchHub remains usable without recovery notifications.",
                nextAction: "Open System Settings")
        case .restricted:
            .init(
                reason: reason, dataImplication: dataImplication,
                declineEffect: "This Mac manages or restricts Notifications.",
                nextAction: "Contact your Mac administrator")
        case .unavailable:
            .init(
                reason: reason, dataImplication: dataImplication,
                declineEffect: "Notifications are unavailable on this Mac.",
                nextAction: "No recovery action is available")
        }
    }
}
