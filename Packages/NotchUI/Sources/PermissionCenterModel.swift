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
    public private(set) var isShowingMicrophoneExplanation = false
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

    public func beginXiaozhiMicrophoneConsent() {
        isShowingMicrophoneExplanation = true
    }

    public func confirmXiaozhiMicrophoneConsent() async {
        guard isShowingMicrophoneExplanation else { return }
        _ = await coordinator.request(
            .microphone,
            context: .init(
                featureID: PermissionFeatureID.xiaozhi,
                reason: "Start a Xiaozhi voice conversation.",
                initiatedByUser: true,
                source: .settings,
                explanationAcknowledged: true
            )
        )
        isShowingMicrophoneExplanation = false
        await load()
    }

    public func dismissMicrophoneExplanation() {
        isShowingMicrophoneExplanation = false
    }

    public func openSystemSettings() async -> Bool {
        await coordinator.openSystemSettings(for: .notifications)
    }

    public func openMicrophoneSystemSettings() async -> Bool {
        await coordinator.openSystemSettings(for: .microphone)
    }
}
