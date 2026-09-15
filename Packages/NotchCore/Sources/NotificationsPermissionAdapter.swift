import AppKit
import UserNotifications

/// The only F5 adapter permitted to call the Notifications authorization API.
public struct NotificationsPermissionAdapter: PermissionAdapter {
    public init() {}

    public func status(for kind: PermissionKind) async -> PermissionStatus {
        guard kind == .notifications else { return .unavailable }
        return await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: Self.status(for: settings.authorizationStatus))
            }
        }
    }

    public func requestAuthorization(for kind: PermissionKind) async -> PermissionStatus {
        guard kind == .notifications else { return .unavailable }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
            return granted ? .authorized : await status(for: kind)
        } catch {
            return .unavailable
        }
    }

    public func openSystemSettings(for kind: PermissionKind) async -> Bool {
        guard kind == .notifications else { return false }
        let notificationsPane = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
        return await MainActor.run { NSWorkspace.shared.open(notificationsPane) }
    }

    private static func status(for value: UNAuthorizationStatus) -> PermissionStatus {
        switch value {
        case .notDetermined:
            .notDetermined
        case .authorized, .provisional, .ephemeral:
            .authorized
        case .denied:
            .denied
        @unknown default:
            .unavailable
        }
    }
}
