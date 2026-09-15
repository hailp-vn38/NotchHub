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
