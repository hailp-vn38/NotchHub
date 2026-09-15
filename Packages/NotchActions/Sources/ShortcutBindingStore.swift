import NotchCore
import NotchDomain

public enum ShortcutBindingOutcome: Equatable, Sendable {
    case saved
    case conflict(existing: ShortcutBinding)
    case rejected
    case persistenceFailed
    case readOnly
}

public struct ShortcutBindingSnapshot: Equatable, Sendable {
    public let activeBindings: [ShortcutBinding]
    public let unavailableBindings: [ShortcutBinding]
    public let disabledBindings: [ShortcutBinding]

    public init(
        activeBindings: [ShortcutBinding],
        unavailableBindings: [ShortcutBinding],
        disabledBindings: [ShortcutBinding]
    ) {
        self.activeBindings = activeBindings
        self.unavailableBindings = unavailableBindings
        self.disabledBindings = disabledBindings
    }
}

public actor ShortcutBindingStore {
    private let settingsStore: SettingsStore
    private var bindings: [ShortcutBinding] = []
    private var availableActionIDs: Set<ActionID> = []
    private var isLoaded = false

    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    public func replaceAvailableActionIDs(_ actionIDs: Set<ActionID>) {
        availableActionIDs = actionIDs
    }

    public func snapshot() async -> ShortcutBindingSnapshot {
        await loadIfNeeded()
        return .init(
            activeBindings: bindings.filter { $0.isEnabled && availableActionIDs.contains($0.actionID) },
            unavailableBindings: bindings.filter { $0.isEnabled && !availableActionIDs.contains($0.actionID) },
            disabledBindings: bindings.filter { !$0.isEnabled }
        )
    }

    public func bind(_ binding: ShortcutBinding) async -> ShortcutBindingOutcome {
        await loadIfNeeded()
        guard binding.isValid else { return .rejected }
        if let existing = bindings.first(where: {
            $0.actionID != binding.actionID && $0.isEnabled && binding.isEnabled
                && $0.key == binding.key && $0.modifiers == binding.modifiers
        }) {
            return .conflict(existing: existing)
        }
        let candidate = bindings.filter { $0.actionID != binding.actionID } + [binding]
        return await persist(candidate)
    }

    public func clearBinding(for actionID: ActionID) async -> ShortcutBindingOutcome {
        await loadIfNeeded()
        return await persist(bindings.filter { $0.actionID != actionID })
    }

    public func setEnabled(_ isEnabled: Bool, for actionID: ActionID) async -> ShortcutBindingOutcome {
        await loadIfNeeded()
        guard let binding = bindings.first(where: { $0.actionID == actionID }) else { return .rejected }
        if isEnabled,
            let existing = bindings.first(where: {
                $0.actionID != actionID && $0.isEnabled
                    && $0.key == binding.key && $0.modifiers == binding.modifiers
            })
        {
            return .conflict(existing: existing)
        }
        let candidate = bindings.map {
            $0.actionID == actionID
                ? .init(
                    actionID: binding.actionID, key: binding.key, modifiers: binding.modifiers, isEnabled: isEnabled)
                : $0
        }
        return await persist(candidate)
    }

    private func loadIfNeeded() async {
        guard !isLoaded else { return }
        bindings = (await settingsStore.load()).settings.shortcuts.bindings.filter(\.isValid)
        isLoaded = true
    }

    private func persist(_ candidate: [ShortcutBinding]) async -> ShortcutBindingOutcome {
        let result = await settingsStore.mutate(.shortcutBindings(candidate))
        switch result.outcome {
        case .saved:
            bindings = candidate
            return .saved
        case .readOnly: return .readOnly
        case .persistenceFailed: return .persistenceFailed
        case .rejected: return .rejected
        }
    }
}
