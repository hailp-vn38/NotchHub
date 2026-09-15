import AppKit
import AVFoundation
import NotchCore

public struct XiaozhiMicrophonePermissionAdapter: PermissionAdapter {
    public init() {}

    public func status(for kind: PermissionKind) async -> PermissionStatus {
        guard kind == .microphone else { return .unavailable }
        return switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .unavailable
        }
    }

    public func requestAuthorization(for kind: PermissionKind) async -> PermissionStatus {
        guard kind == .microphone else { return .unavailable }
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        return await status(for: kind)
    }

    public func openSystemSettings(for kind: PermissionKind) async -> Bool {
        guard kind == .microphone,
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        else { return false }
        return NSWorkspace.shared.open(url)
    }
}
