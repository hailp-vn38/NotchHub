import NotchCore
import Observation

@MainActor
@Observable
public final class PermissionCenterModel {
    public private(set) var notificationsStatus: PermissionStatus = .notDetermined
    public private(set) var notificationsGuidance = PermissionGuidance(
        reason: "", dataImplication: "", declineEffect: "", nextAction: "")
    public private(set) var isShowingExplanation = false
    public let informationalCapabilities: [PermissionKind] = [
        .accessibility, .microphone, .calendar, .reminders, .camera, .screenRecording, .automation,
    ]
    private let coordinator: PermissionCoordinator

    public init(coordinator: PermissionCoordinator) {
        self.coordinator = coordinator
    }

    public func load() async {
        await coordinator.refresh()
        let row = await coordinator.snapshot().row(for: .notifications)
        notificationsStatus = row?.status ?? .notDetermined
        notificationsGuidance = row?.guidance ?? notificationsGuidance
    }

    public func beginNotificationsRecoveryOptIn() {
        isShowingExplanation = true
    }

    public func confirmNotificationsRecoveryOptIn() async {
        guard isShowingExplanation else { return }
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
        isShowingExplanation = false
        await load()
    }

    public func dismissExplanation() {
        isShowingExplanation = false
    }

    public func openSystemSettings() async -> Bool {
        await coordinator.openSystemSettings(for: .notifications)
    }
}
