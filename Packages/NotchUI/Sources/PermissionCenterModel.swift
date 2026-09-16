import NotchCore
import Observation

@MainActor
@Observable
public final class PermissionCenterModel {
    public private(set) var notificationsStatus: PermissionStatus = .notDetermined
    public private(set) var notificationsGuidance = PermissionGuidance(
        reason: "", dataImplication: "", declineEffect: "", nextAction: "")
    public private(set) var isShowingExplanation = false
    public private(set) var microphoneStatus: PermissionStatus = .notDetermined
    public private(set) var microphoneGuidance = PermissionGuidance(
        reason: "", dataImplication: "", declineEffect: "", nextAction: "")
    public let informationalCapabilities: [PermissionKind] = [
        .accessibility, .calendar, .reminders, .camera, .screenRecording, .automation,
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
        let microphone = await coordinator.snapshot().row(for: .microphone)
        microphoneStatus = microphone?.status ?? .notDetermined
        microphoneGuidance = microphone?.guidance ?? microphoneGuidance
    }

    public func beginNotificationsRecoveryOptIn() {
        isShowingExplanation = true
    }

    public func confirmNotificationsRecoveryOptIn() async {
        guard isShowingExplanation else { return }
        let result = await coordinator.request(
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
        if result != .authorized {
            _ = await coordinator.openSystemSettings(for: .notifications)
        }
    }

    public func dismissExplanation() {
        isShowingExplanation = false
    }

    public func requestXiaozhiMicrophone() async {
        let result = await coordinator.request(
            .microphone,
            context: .init(
                featureID: PermissionFeatureID.xiaozhi,
                reason: "Start a Xiaozhi voice conversation.",
                initiatedByUser: true,
                source: .settings,
                explanationAcknowledged: true
            )
        )
        await load()
        if result != .authorized {
            _ = await coordinator.openSystemSettings(for: .microphone)
        }
    }

    public func openSystemSettings() async -> Bool {
        await coordinator.openSystemSettings(for: .notifications)
    }

    public func openMicrophoneSystemSettings() async -> Bool {
        await coordinator.openSystemSettings(for: .microphone)
    }
}
