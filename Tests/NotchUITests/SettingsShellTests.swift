import NotchCore
import NotchUI
import Testing

@Test("Settings shell exposes the stable foundation navigation")
@MainActor
func exposesFoundationRoutesInDocumentedOrder() {
    let model = SettingsShellModel()

    #expect(
        model.routes == [
            .general, .appearance, .notchBehavior, .shortcuts, .permissions,
            .actions, .modules, .diagnostics, .about,
        ]
    )
    #expect(model.selectedRoute == .general)
    #expect(model.routeState(for: .appearance).isInteractive)
    #expect(model.routeState(for: .shortcuts).owningPhase == .f6)
}

@Test("Settings shell keeps future routes unavailable without side effects")
@MainActor
func keepsFutureRoutesReadOnly() {
    let model = SettingsShellModel()

    model.select(.permissions)
    let before = model.sessionMotionPreference
    let outcome = model.setSessionMotionPreference(.reduced)

    #expect(model.selectedRoute == .permissions)
    #expect(model.routeState(for: .permissions).isInteractive == false)
    #expect(outcome == .unavailable(owner: .f5))
    #expect(model.sessionMotionPreference == before)
}

@Test("Appearance preview is session-only and explicitly resettable")
@MainActor
func appliesSafeAppearancePreviewWithoutPersistence() {
    let model = SettingsShellModel()

    model.select(.appearance)
    #expect(model.setSessionMotionPreference(.reduced) == .appliedSessionOnly)
    #expect(model.sessionMotionPreference == .reduced)
    #expect(model.isReducedMotion(systemPreference: false))

    model.resetSessionPreview()
    #expect(model.sessionMotionPreference == .system)
    #expect(model.isReducedMotion(systemPreference: false) == false)
    #expect(model.isReducedMotion(systemPreference: true))
}

@Test("Permissions route stays passive until the user confirms its explanation")
@MainActor
func keepsPermissionsPassiveUntilConfirmation() async {
    let adapter = SettingsPermissionAdapter()
    let permissions = PermissionCenterModel(coordinator: PermissionCoordinator(adapter: adapter))
    let model = SettingsShellModel(permissionCenter: permissions)

    model.select(.permissions)
    #expect(model.routeState(for: .permissions).isInteractive)
    #expect(await adapter.requestCount == 0)

    await permissions.load()
    permissions.beginNotificationsRecoveryOptIn()
    #expect(permissions.isShowingExplanation)
    #expect(await adapter.requestCount == 0)

    await permissions.confirmNotificationsRecoveryOptIn()
    #expect(await adapter.requestCount == 1)
    #expect(permissions.notificationsStatus == .authorized)
    #expect(permissions.notificationsGuidance.nextAction == "Recovery notifications are enabled")
    #expect(
        permissions.informationalCapabilities == [
            .accessibility, .microphone, .calendar, .reminders, .camera, .screenRecording, .automation,
        ])
}

@Test("Permissions model projects a restricted state without a System Settings recovery action")
@MainActor
func projectsRestrictedPermissionGuidance() async {
    let permissions = PermissionCenterModel(
        coordinator: PermissionCoordinator(adapter: SettingsPermissionAdapter(status: .restricted)))

    await permissions.load()

    #expect(permissions.notificationsStatus == .restricted)
    #expect(permissions.notificationsGuidance.nextAction == "Contact your Mac administrator")
}

private actor SettingsPermissionAdapter: PermissionAdapter {
    private var status: PermissionStatus
    private(set) var requestCount = 0

    init(status: PermissionStatus = .notDetermined) {
        self.status = status
    }

    func status(for _: PermissionKind) async -> PermissionStatus { status }

    func requestAuthorization(for _: PermissionKind) async -> PermissionStatus {
        requestCount += 1
        status = .authorized
        return status
    }

    func openSystemSettings(for _: PermissionKind) async -> Bool { true }
}
