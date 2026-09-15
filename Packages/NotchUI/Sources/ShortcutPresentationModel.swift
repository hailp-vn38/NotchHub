import NotchActions
import NotchDomain
import Observation

public enum ShortcutPresentationState: Equatable, Sendable {
    case empty
    case unavailable(bindings: [ShortcutBinding], disabledBindings: [ShortcutBinding])
    case available(
        bindings: [ShortcutBinding], unavailableBindings: [ShortcutBinding], disabledBindings: [ShortcutBinding])
}

@MainActor
@Observable
public final class ShortcutPresentationModel {
    private let bindingStore: ShortcutBindingStore
    public private(set) var state: ShortcutPresentationState = .empty
    public private(set) var feedback: String?

    public init(bindingStore: ShortcutBindingStore) {
        self.bindingStore = bindingStore
    }

    public func load() async {
        let snapshot = await bindingStore.snapshot()
        if snapshot.activeBindings.isEmpty {
            state =
                snapshot.unavailableBindings.isEmpty && snapshot.disabledBindings.isEmpty
                ? .empty
                : .unavailable(bindings: snapshot.unavailableBindings, disabledBindings: snapshot.disabledBindings)
        } else {
            state = .available(
                bindings: snapshot.activeBindings,
                unavailableBindings: snapshot.unavailableBindings,
                disabledBindings: snapshot.disabledBindings
            )
        }
    }

    public func clearBinding(for actionID: ActionID) async {
        _ = await bindingStore.clearBinding(for: actionID)
        await load()
    }

    public func setEnabled(_ isEnabled: Bool, for actionID: ActionID) async {
        let outcome = await bindingStore.setEnabled(isEnabled, for: actionID)
        if case .conflict(let existing) = outcome {
            feedback = "Shortcut is already assigned to \(existing.actionID.rawValue)."
        } else {
            feedback = nil
        }
        await load()
    }
}
