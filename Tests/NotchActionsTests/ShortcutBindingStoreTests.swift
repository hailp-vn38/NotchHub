import Foundation
import NotchActions
import NotchCore
import NotchDomain
import Testing

@Test("Shortcut binding remains unavailable until its Action is registered")
func retainsUnavailableBindingAndActivatesItWhenItsActionAppears() async throws {
    let settingsStore = SettingsStore(backend: ShortcutMemorySettingsBackend())
    let store = ShortcutBindingStore(settingsStore: settingsStore)
    let action = try #require(ActionID("app.openSettings"))
    let binding = ShortcutBinding(actionID: action, key: "s", modifiers: [.command])

    #expect(await store.bind(binding) == .saved)
    #expect(await store.snapshot().unavailableBindings == [binding])

    await store.replaceAvailableActionIDs([action])
    #expect(await store.snapshot().activeBindings == [binding])
}

@Test("Conflicting shortcut leaves the existing binding intact")
func rejectsConflictingBindingWithoutReplacement() async throws {
    let settingsStore = SettingsStore(backend: ShortcutMemorySettingsBackend())
    let store = ShortcutBindingStore(settingsStore: settingsStore)
    let firstAction = try #require(ActionID("app.openSettings"))
    let secondAction = try #require(ActionID("app.openDiagnostics"))
    let first = ShortcutBinding(actionID: firstAction, key: "s", modifiers: [.command])
    let conflicting = ShortcutBinding(actionID: secondAction, key: "s", modifiers: [.command])

    #expect(await store.bind(first) == .saved)
    #expect(await store.bind(conflicting) == .conflict(existing: first))
    #expect(await store.snapshot().unavailableBindings == [first])
}

@Test("Shortcut binding persists across a new store instance")
func persistsBindingAcrossRelaunch() async throws {
    let backend = ShortcutMemorySettingsBackend()
    let action = try #require(ActionID("app.openSettings"))
    let binding = ShortcutBinding(actionID: action, key: "s", modifiers: [.command])

    let first = ShortcutBindingStore(settingsStore: SettingsStore(backend: backend))
    #expect(await first.bind(binding) == .saved)

    let relaunched = ShortcutBindingStore(settingsStore: SettingsStore(backend: backend))
    #expect(await relaunched.snapshot().unavailableBindings == [binding])
}

@Test("Disabling a binding removes its active chord and permits a replacement")
func disablesBindingWithoutRetainingItsConflict() async throws {
    let settingsStore = SettingsStore(backend: ShortcutMemorySettingsBackend())
    let store = ShortcutBindingStore(settingsStore: settingsStore)
    let firstAction = try #require(ActionID("app.openSettings"))
    let secondAction = try #require(ActionID("app.openDiagnostics"))
    let first = ShortcutBinding(actionID: firstAction, key: "s", modifiers: [.command])
    let replacement = ShortcutBinding(actionID: secondAction, key: "s", modifiers: [.command])

    #expect(await store.bind(first) == .saved)
    #expect(await store.setEnabled(false, for: firstAction) == .saved)
    #expect(
        await store.snapshot().disabledBindings == [
            ShortcutBinding(
                actionID: firstAction, key: "s", modifiers: [.command], isEnabled: false
            )
        ])
    #expect(await store.bind(replacement) == .saved)
    #expect(await store.setEnabled(true, for: firstAction) == .conflict(existing: replacement))
}

private actor ShortcutMemorySettingsBackend: SettingsBackend {
    private var active: Data?

    func readActive() throws -> Data? { active }

    func replaceActive(with data: Data) throws { active = data }

    func quarantine(_: Data) throws {}
}
