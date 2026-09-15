import Foundation
import NotchDomain

public enum ModuleResourceKind: String, CaseIterable, Sendable {
    case task, timer, observer, subscription, action, surfaceContribution, socket, cache
}

public actor ModuleLifetime {
    private var resources: [ModuleResourceKind: Set<String>] = [:]
    private var contributions: [SurfaceContributionDescriptor] = []
    private var revoked = false
    private var cleanups: [@Sendable () async -> Void] = []
    private let contributionsDidChange: @Sendable () async -> Void

    public init(contributionsDidChange: @escaping @Sendable () async -> Void = {}) {
        self.contributionsDidChange = contributionsDidChange
    }

    public func register(_ kind: ModuleResourceKind, named name: String) {
        guard !revoked else { return }
        resources[kind, default: []].insert(name)
    }

    /// Registers a real owned resource; cleanup is run once on lifetime revocation.
    public func register(
        _ kind: ModuleResourceKind,
        named name: String,
        cleanup: @escaping @Sendable () async -> Void
    ) {
        guard !revoked else {
            Task { await cleanup() }
            return
        }
        resources[kind, default: []].insert(name)
        cleanups.append(cleanup)
    }

    public func register(_ contribution: SurfaceContributionDescriptor) {
        guard !revoked else { return }
        contributions.removeAll { $0.slot == contribution.slot }
        contributions.append(contribution)
        resources[.surfaceContribution, default: []].insert(contribution.id)
        Task { await contributionsDidChange() }
    }

    /// Replaces a module-owned projection without extending its lifetime.
    public func update(_ contribution: SurfaceContributionDescriptor) {
        register(contribution)
    }

    public func revoke() async {
        guard !revoked else { return }
        revoked = true
        let ownedCleanups = cleanups
        cleanups.removeAll()
        resources.removeAll()
        contributions.removeAll()
        await contributionsDidChange()
        for cleanup in ownedCleanups.reversed() { await cleanup() }
    }

    public var activeResourceCount: Int { resources.values.reduce(0) { $0 + $1.count } }
    public var activeContributions: [SurfaceContributionDescriptor] { contributions }
}

public struct ModuleAction: Sendable {
    public let definition: ActionDefinition
    public let invoke: @Sendable () async -> Void

    public init(definition: ActionDefinition, invoke: @escaping @Sendable () async -> Void) {
        self.definition = definition
        self.invoke = invoke
    }
}

public actor ModuleActionRegistry {
    private var actions: [ActionID: ModuleAction] = [:]
    public init() {}

    public func register(_ action: ModuleAction, lifetime: ModuleLifetime) async -> Bool {
        guard actions[action.definition.id] == nil else { return false }
        actions[action.definition.id] = action
        let id = action.definition.id
        await lifetime.register(.action, named: id.rawValue) { [weak self] in
            await self?.remove(id)
        }
        return true
    }

    public func invoke(_ id: ActionID) async { await actions[id]?.invoke() }
    public func definitions() -> [ActionDefinition] { actions.values.map(\.definition) }
    private func remove(_ id: ActionID) { actions[id] = nil }
}

public protocol ModuleEventPublisher: Sendable {
    func publish(_ event: ModuleEvent) async
}

public actor RecordingModuleEventPublisher: ModuleEventPublisher {
    public private(set) var events: [ModuleEvent] = []
    public init() {}
    public func publish(_ event: ModuleEvent) { events.append(event) }
}

public struct ModuleContext: Sendable {
    public let lifetime: ModuleLifetime
    public let eventPublisher: any ModuleEventPublisher
    public let actions: ModuleActionRegistry

    public init(
        lifetime: ModuleLifetime,
        eventPublisher: any ModuleEventPublisher,
        actions: ModuleActionRegistry
    ) {
        self.lifetime = lifetime
        self.eventPublisher = eventPublisher
        self.actions = actions
    }
}

public enum ModuleCommand: Sendable {
    case simulateFailure
    /// Ends an interactive session before the host becomes unavailable.
    case endTransientSession
}
public enum ModuleCommandResult: Equatable, Sendable { case handled, ignored }

public protocol NotchModule: Sendable {
    var id: ModuleID { get }
    var metadata: ModuleMetadata { get }
    func start(context: ModuleContext) async throws
    func stop() async
    func handle(_ command: ModuleCommand) async throws -> ModuleCommandResult
}

extension NotchModule {
    public func start(context _: ModuleContext) async throws {}
    public func stop() async {}
    public func handle(_: ModuleCommand) async throws -> ModuleCommandResult { .ignored }
}

public enum ModuleRuntimeError: Error, Equatable, Sendable { case timeout }

/// The sole authority for statically-linked Module lifecycle and health.
public actor ModuleRuntime {
    private struct Entry: Sendable {
        let module: any NotchModule
        var health: ModuleHealth
        var lifetime: ModuleLifetime?
    }

    private var entries: [ModuleID: Entry] = [:]
    private var registrationOrder: [ModuleID] = []
    private let eventPublisher: any ModuleEventPublisher
    private let settingsStore: SettingsStore?
    private var contributionContinuations: [UUID: AsyncStream<[SurfaceContributionDescriptor]>.Continuation] = [:]
    public let actions: ModuleActionRegistry

    public init(
        settingsStore: SettingsStore? = nil,
        eventPublisher: any ModuleEventPublisher = RecordingModuleEventPublisher(),
        actions: ModuleActionRegistry = .init()
    ) {
        self.settingsStore = settingsStore
        self.eventPublisher = eventPublisher
        self.actions = actions
    }

    public func register(_ module: any NotchModule, enabled: Bool = false) {
        guard entries[module.id] == nil else { return }
        entries[module.id] = .init(
            module: module,
            health: .init(id: module.id, isEnabled: enabled),
            lifetime: nil)
        registrationOrder.append(module.id)
    }

    public func health(for id: ModuleID) -> ModuleHealth? { entries[id]?.health }
    public func healthSnapshot() -> [ModuleHealth] { registrationOrder.compactMap { entries[$0]?.health } }

    public func activeResourceCount(for id: ModuleID) async -> Int {
        await entries[id]?.lifetime?.activeResourceCount ?? 0
    }

    public func contributions(for id: ModuleID) async -> [SurfaceContributionDescriptor] {
        await entries[id]?.lifetime?.activeContributions ?? []
    }

    public func allContributions() async -> [SurfaceContributionDescriptor] {
        var result: [SurfaceContributionDescriptor] = []
        for id in registrationOrder {
            result += await entries[id]?.lifetime?.activeContributions ?? []
        }
        return result
    }

    public func contributionUpdates() -> AsyncStream<[SurfaceContributionDescriptor]> {
        let id = UUID()
        return AsyncStream { continuation in
            contributionContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContributionContinuation(id) }
            }
            Task { [weak self] in
                guard let self else { return }
                continuation.yield(await self.allContributions())
            }
        }
    }

    public func start(_ id: ModuleID) async {
        guard var entry = entries[id], entry.health.isEnabled,
            entry.health.state == .registered || entry.health.state == .stopped
        else { return }
        let lifetime = ModuleLifetime { [weak self] in await self?.publishContributionUpdate() }
        entry.lifetime = lifetime
        entry.health = .init(
            id: id, state: .starting, isEnabled: true,
            lastStartedAt: entry.health.lastStartedAt, lastError: nil,
            restartCount: entry.health.restartCount)
        entries[id] = entry
        let context = ModuleContext(lifetime: lifetime, eventPublisher: eventPublisher, actions: actions)
        let module = entry.module
        do {
            try await bounded(.seconds(5)) { try await module.start(context: context) }
            guard var current = entries[id], current.health.state == .starting, current.health.isEnabled else { return }
            current.health = .init(
                id: id, state: .running, isEnabled: true, lastStartedAt: .now,
                restartCount: current.health.restartCount)
            entries[id] = current
            await eventPublisher.publish(.init(moduleID: id, type: EventType("module.started")!))
        } catch {
            await fail(id, error: error, stopping: true)
        }
    }

    public func setEnabled(_ enabled: Bool, for id: ModuleID) async {
        guard var entry = entries[id] else { return }
        if enabled {
            guard !entry.health.isEnabled else { return }
            entry.health = .init(
                id: id, state: .stopped, isEnabled: true,
                lastStartedAt: entry.health.lastStartedAt, lastError: nil,
                restartCount: entry.health.restartCount)
            entries[id] = entry
            if let settingsStore {
                _ = await settingsStore.mutate(.moduleEnabled(true, id: id))
            }
            await start(id)
            return
        }
        guard entry.health.isEnabled else { return }
        entry.health = .init(
            id: id, state: .stopping, isEnabled: false,
            lastStartedAt: entry.health.lastStartedAt, lastError: nil,
            restartCount: entry.health.restartCount)
        entries[id] = entry
        if let settingsStore { _ = await settingsStore.mutate(.moduleEnabled(enabled, id: id)) }
        await stopEntry(id, terminalState: .stopped, enabled: false)
    }

    public func restart(_ id: ModuleID) async {
        guard let entry = entries[id], entry.health.isEnabled,
            entry.health.state == .running || entry.health.state == .suspended || entry.health.state == .failed
        else { return }
        await stopEntry(id, terminalState: .stopped, enabled: true)
        guard var current = entries[id] else { return }
        current.health = .init(
            id: id, state: .stopped, isEnabled: true,
            lastStartedAt: current.health.lastStartedAt,
            restartCount: current.health.restartCount + 1)
        entries[id] = current
        await start(id)
    }

    public func restartRuntime() async {
        let enabled = registrationOrder.filter { entries[$0]?.health.isEnabled == true }
        for id in enabled.reversed() { await stopEntry(id, terminalState: .stopped, enabled: true) }
        for id in enabled { await start(id) }
    }

    public func shutdown() async {
        for id in registrationOrder.reversed() {
            guard entries[id]?.health.isEnabled == true else { continue }
            await stopEntry(id, terminalState: .stopped, enabled: true)
        }
    }

    public func send(_ command: ModuleCommand, to id: ModuleID) async {
        guard let entry = entries[id], entry.health.state == .running else { return }
        do { _ = try await entry.module.handle(command) } catch { await fail(id, error: error, stopping: true) }
    }

    private func stopEntry(_ id: ModuleID, terminalState: ModuleLifecycleState, enabled: Bool) async {
        guard let entry = entries[id] else { return }
        _ = try? await bounded(.seconds(2)) { await entry.module.stop() }
        await entry.lifetime?.revoke()
        guard var current = entries[id] else { return }
        current.lifetime = nil
        current.health = .init(
            id: id, state: terminalState, isEnabled: enabled,
            lastStartedAt: current.health.lastStartedAt,
            lastError: terminalState == .failed ? current.health.lastError : nil,
            restartCount: current.health.restartCount)
        entries[id] = current
    }

    private func fail(_ id: ModuleID, error: Error, stopping: Bool) async {
        guard let entry = entries[id] else { return }
        if stopping { await stopEntry(id, terminalState: .failed, enabled: entry.health.isEnabled) }
        guard var current = entries[id] else { return }
        let message = error is ModuleRuntimeError ? "Module operation timed out." : "Module operation failed."
        current.health = .init(
            id: id, state: .failed, isEnabled: current.health.isEnabled,
            lastStartedAt: current.health.lastStartedAt, lastError: message,
            restartCount: current.health.restartCount)
        entries[id] = current
    }

    private func publishContributionUpdate() async {
        let contributions = await allContributions()
        for continuation in contributionContinuations.values { continuation.yield(contributions) }
    }

    private func removeContributionContinuation(_ id: UUID) {
        contributionContinuations[id] = nil
    }

    private func bounded<T: Sendable>(_ duration: Duration, operation: @escaping @Sendable () async throws -> T)
        async throws -> T
    {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask(operation: operation)
            group.addTask {
                try await Task.sleep(for: duration)
                throw ModuleRuntimeError.timeout
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
}
