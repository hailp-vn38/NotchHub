import NotchCore
import Testing

@Test("Permission Coordinator rejects passive requests and authorizes confirmed Notifications opt-in")
func authorizesOnlyConfirmedNotificationsOptIn() async {
    let adapter = RecordingPermissionAdapter(status: .notDetermined, requestResult: .authorized)
    let coordinator = PermissionCoordinator(adapter: adapter)
    let context = PermissionRequestContext(
        featureID: PermissionFeatureID.recoveryNotifications,
        reason: "Receive Permission Center recovery notifications.",
        initiatedByUser: true,
        source: .settings,
        explanationAcknowledged: true
    )

    let passive = await coordinator.request(
        .notifications,
        context: .init(
            featureID: context.featureID,
            reason: context.reason,
            initiatedByUser: false,
            source: .settings,
            explanationAcknowledged: true
        )
    )
    #expect(passive == .rejected(.userInitiationRequired))
    #expect(await adapter.requestCount == 0)

    let result = await coordinator.request(.notifications, context: context)
    #expect(result == .authorized)
    #expect(await adapter.requestCount == 1)
    #expect(await coordinator.snapshot().row(for: .notifications)?.status == .authorized)
}

@Test("Permission Coordinator refreshes denied Notifications and opens System Settings recovery")
func refreshesDeniedNotificationsAndOpensRecovery() async {
    let adapter = RecordingPermissionAdapter(status: .denied, requestResult: .denied)
    let coordinator = PermissionCoordinator(adapter: adapter)

    await coordinator.refresh()

    #expect(await coordinator.snapshot().row(for: .notifications)?.status == .denied)
    #expect(await coordinator.openSystemSettings(for: .notifications))
    #expect(await adapter.openSettingsCount == 1)
}

@Test("Permission Coordinator treats denied, restricted, and unavailable as recovery-only states")
func doesNotRetryNonRequestableNotificationsStates() async {
    let context = confirmedNotificationsContext()
    for status in [PermissionStatus.denied, .restricted, .unavailable] {
        let adapter = RecordingPermissionAdapter(status: status, requestResult: .authorized)
        let coordinator = PermissionCoordinator(adapter: adapter)

        let result = await coordinator.request(.notifications, context: context)

        switch status {
        case .denied: #expect(result == .denied)
        case .restricted: #expect(result == .restricted)
        case .unavailable: #expect(result == .unavailable)
        default: Issue.record("Unexpected test status")
        }
        #expect(await adapter.requestCount == 0)
    }
}

@Test("Permission Coordinator records a denied confirmation and never prompts it again")
func handlesDeniedConfirmationWithoutRetrying() async {
    let adapter = RecordingPermissionAdapter(status: .notDetermined, requestResult: .denied)
    let coordinator = PermissionCoordinator(adapter: adapter)
    let context = confirmedNotificationsContext()

    #expect(await coordinator.request(.notifications, context: context) == .denied)
    #expect(await coordinator.snapshot().row(for: .notifications)?.status == .denied)
    #expect(await coordinator.request(.notifications, context: context) == .denied)
    #expect(await adapter.requestCount == 1)
}

@Test("Permission Coordinator refreshes an externally revoked authorization")
func refreshesExternallyRevokedAuthorization() async {
    let adapter = RecordingPermissionAdapter(status: .authorized, requestResult: .authorized)
    let coordinator = PermissionCoordinator(adapter: adapter)
    await coordinator.refresh()
    await adapter.setStatus(.denied)

    await coordinator.refresh()

    #expect(await coordinator.snapshot().row(for: .notifications)?.status == .denied)
}

@Test("Permission Coordinator rejects malformed and non-Settings requests before the adapter")
func rejectsInvalidRequestsBeforeAdapter() async {
    let adapter = RecordingPermissionAdapter(status: .notDetermined, requestResult: .authorized)
    let coordinator = PermissionCoordinator(adapter: adapter)
    let context = confirmedNotificationsContext()
    let invalid: [(PermissionRequestContext, PermissionRequestRejection)] = [
        (
            .init(
                featureID: context.featureID, reason: context.reason, initiatedByUser: false, source: .settings,
                explanationAcknowledged: true), .userInitiationRequired
        ),
        (
            .init(
                featureID: context.featureID, reason: context.reason, initiatedByUser: true, source: .settings,
                explanationAcknowledged: false), .explanationRequired
        ),
        (
            .init(
                featureID: context.featureID, reason: "  ", initiatedByUser: true, source: .settings,
                explanationAcknowledged: true), .reasonRequired
        ),
        (
            .init(
                featureID: "unknown", reason: context.reason, initiatedByUser: true, source: .settings,
                explanationAcknowledged: true), .unknownFeature
        ),
        (
            .init(
                featureID: context.featureID, reason: context.reason, initiatedByUser: true,
                source: .featureInteraction, explanationAcknowledged: true), .sourceNotAllowed
        ),
        (
            .init(
                featureID: context.featureID, reason: context.reason, initiatedByUser: true, source: .recovery,
                explanationAcknowledged: true), .recoveryCannotPrompt
        ),
    ]

    for (invalidContext, rejection) in invalid {
        #expect(await coordinator.request(.notifications, context: invalidContext) == .rejected(rejection))
    }
    #expect(await adapter.requestCount == 0)
}

@Test("Permission Coordinator deduplicates concurrent Notifications confirmations")
func deduplicatesConcurrentNotificationsConfirmations() async {
    let adapter = DelayedPermissionAdapter()
    let coordinator = PermissionCoordinator(adapter: adapter)
    let context = PermissionRequestContext(
        featureID: PermissionFeatureID.recoveryNotifications,
        reason: "Receive Permission Center recovery notifications.",
        initiatedByUser: true,
        source: .settings,
        explanationAcknowledged: true
    )

    async let first = coordinator.request(.notifications, context: context)
    async let second = coordinator.request(.notifications, context: context)

    #expect(await first == .authorized)
    #expect(await second == .authorized)
    #expect(await adapter.requestCount == 1)
}

@Test("Permission Coordinator emits sanitized audit metadata for a granted request")
func emitsSanitizedPermissionAuditMetadata() async throws {
    let audit = RecordingPermissionAuditSink()
    let coordinator = PermissionCoordinator(
        adapter: RecordingPermissionAdapter(status: .notDetermined, requestResult: .authorized),
        auditSink: audit
    )

    _ = await coordinator.request(
        .notifications,
        context: .init(
            featureID: PermissionFeatureID.recoveryNotifications,
            reason: "Receive Permission Center recovery notifications.",
            initiatedByUser: true,
            source: .settings,
            explanationAcknowledged: true
        )
    )

    let event = try #require(await audit.events.only)
    #expect(event.kind == .notifications)
    #expect(event.before == .notDetermined)
    #expect(event.after == .authorized)
    #expect(event.featureID == PermissionFeatureID.recoveryNotifications)
    #expect(event.source == .settings)
    #expect(event.explanationShown)
    #expect(event.outcome == .authorized)
    #expect(event.appVersion == "unknown")
}

@Test("Permission Coordinator projects textual recovery guidance and preserves Settings failures")
func projectsGuidanceAndReportsSettingsFailure() async {
    let adapter = RecordingPermissionAdapter(status: .denied, requestResult: .denied, openSettingsResult: false)
    let coordinator = PermissionCoordinator(adapter: adapter)
    await coordinator.refresh()

    let row = await coordinator.snapshot().row(for: .notifications)

    #expect(row?.guidance.nextAction == "Open System Settings")
    #expect(row?.guidance.dataImplication.contains("transcripts") == true)
    #expect(await coordinator.openSystemSettings(for: .notifications) == false)
}

private actor RecordingPermissionAdapter: PermissionAdapter {
    private var statusValue: PermissionStatus
    private let requestResult: PermissionStatus
    private let openSettingsResult: Bool
    private(set) var requestCount = 0
    private(set) var openSettingsCount = 0

    init(status: PermissionStatus, requestResult: PermissionStatus, openSettingsResult: Bool = true) {
        statusValue = status
        self.requestResult = requestResult
        self.openSettingsResult = openSettingsResult
    }

    func status(for _: PermissionKind) async -> PermissionStatus {
        statusValue
    }

    func requestAuthorization(for _: PermissionKind) async -> PermissionStatus {
        requestCount += 1
        statusValue = requestResult
        return statusValue
    }

    func openSystemSettings(for _: PermissionKind) async -> Bool {
        openSettingsCount += 1
        return openSettingsResult
    }

    func setStatus(_ value: PermissionStatus) {
        statusValue = value
    }
}

private actor DelayedPermissionAdapter: PermissionAdapter {
    private(set) var requestCount = 0

    func status(for _: PermissionKind) async -> PermissionStatus { .notDetermined }

    func requestAuthorization(for _: PermissionKind) async -> PermissionStatus {
        requestCount += 1
        try? await Task.sleep(for: .milliseconds(20))
        return .authorized
    }

    func openSystemSettings(for _: PermissionKind) async -> Bool { true }
}

private actor RecordingPermissionAuditSink: PermissionAuditSinking {
    private(set) var events: [PermissionAuditEvent] = []

    func record(_ event: PermissionAuditEvent) async {
        events.append(event)
    }
}

extension Array {
    fileprivate var only: Element? { count == 1 ? self[0] : nil }
}

private func confirmedNotificationsContext() -> PermissionRequestContext {
    .init(
        featureID: PermissionFeatureID.recoveryNotifications,
        reason: "Receive Permission Center recovery notifications.",
        initiatedByUser: true,
        source: .settings,
        explanationAcknowledged: true
    )
}
