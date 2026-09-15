import Foundation
import NotchActions
import NotchCore
import NotchDomain
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

@Test("Shortcut presentation distinguishes an empty registry from an unavailable binding")
@MainActor
func presentsShortcutFrameworkStates() async throws {
    let store = ShortcutBindingStore(settingsStore: SettingsStore(backend: SettingsMemoryBackend()))
    let model = ShortcutPresentationModel(bindingStore: store)
    let action = try #require(ActionID("app.openSettings"))

    await model.load()
    #expect(model.state == .empty)

    _ = await store.bind(.init(actionID: action, key: "s", modifiers: [.command]))
    await model.load()
    #expect(
        model.state
            == .unavailable(
                bindings: [.init(actionID: action, key: "s", modifiers: [.command])],
                disabledBindings: []
            ))
}

@Test("Shortcut presentation retains disabled bindings")
@MainActor
func presentsDisabledShortcutBinding() async throws {
    let store = ShortcutBindingStore(settingsStore: SettingsStore(backend: SettingsMemoryBackend()))
    let model = ShortcutPresentationModel(bindingStore: store)
    let action = try #require(ActionID("app.openSettings"))
    let binding = ShortcutBinding(actionID: action, key: "s", modifiers: [.command])

    _ = await store.bind(binding)
    _ = await store.setEnabled(false, for: action)
    await model.load()

    #expect(
        model.state
            == .unavailable(
                bindings: [],
                disabledBindings: [
                    .init(actionID: action, key: "s", modifiers: [.command], isEnabled: false)
                ]))
}

@Test("Shortcut presentation reports an enable conflict")
@MainActor
func reportsShortcutEnableConflict() async throws {
    let store = ShortcutBindingStore(settingsStore: SettingsStore(backend: SettingsMemoryBackend()))
    let model = ShortcutPresentationModel(bindingStore: store)
    let firstAction = try #require(ActionID("app.openSettings"))
    let secondAction = try #require(ActionID("app.openDiagnostics"))

    _ = await store.bind(.init(actionID: firstAction, key: "s", modifiers: [.command]))
    _ = await store.setEnabled(false, for: firstAction)
    _ = await store.bind(.init(actionID: secondAction, key: "s", modifiers: [.command]))
    await model.setEnabled(true, for: firstAction)

    #expect(model.feedback == "Shortcut is already assigned to app.openDiagnostics.")
}

@Test("Settings shell activates the Shortcuts route only with its F6 presentation model")
@MainActor
func activatesShortcutRouteAtTheOwnedSeam() {
    let store = ShortcutBindingStore(settingsStore: SettingsStore(backend: SettingsMemoryBackend()))
    let shortcuts = ShortcutPresentationModel(bindingStore: store)
    let model = SettingsShellModel(shortcutPresentation: shortcuts)

    #expect(model.routeState(for: .shortcuts).isInteractive)
    #expect(SettingsShellModel().routeState(for: .shortcuts).isInteractive == false)
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

private actor SettingsMemoryBackend: SettingsBackend {
    private var active: Data?

    func readActive() throws -> Data? { active }

    func replaceActive(with data: Data) throws { active = data }

    func quarantine(_: Data) throws {}
}
