import Foundation

public enum SettingsTheme: String, CaseIterable, Codable, Equatable, Sendable {
    case system
    case light
    case dark
}

public enum ReducedMotionOverride: String, CaseIterable, Codable, Equatable, Sendable {
    case followSystem
    case reduceMotion
}

public enum HoverDelay: Int, CaseIterable, Codable, Equatable, Sendable {
    case milliseconds150 = 150
    case milliseconds300 = 300
    case milliseconds500 = 500

    public var duration: Duration { .milliseconds(rawValue) }
}

public enum AutoCollapseTimeout: Int, CaseIterable, Codable, Equatable, Sendable {
    case seconds2 = 2
    case seconds3 = 3
    case seconds5 = 5

    public var duration: Duration { .seconds(rawValue) }
}

public struct AppearanceSettings: Codable, Equatable, Sendable {
    public var theme: SettingsTheme
    public var reducedMotion: ReducedMotionOverride

    public init(theme: SettingsTheme = .system, reducedMotion: ReducedMotionOverride = .followSystem) {
        self.theme = theme
        self.reducedMotion = reducedMotion
    }
}

public struct NotchBehaviorSettings: Codable, Equatable, Sendable {
    public var hoverDelay: HoverDelay
    public var autoCollapseTimeout: AutoCollapseTimeout

    public init(
        hoverDelay: HoverDelay = .milliseconds300,
        autoCollapseTimeout: AutoCollapseTimeout = .seconds3
    ) {
        self.hoverDelay = hoverDelay
        self.autoCollapseTimeout = autoCollapseTimeout
    }
}

/// The complete, non-secret F4 v1 settings snapshot.
public struct AppSettings: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var appearance: AppearanceSettings
    public var notchBehavior: NotchBehaviorSettings

    public init(
        schemaVersion: Int = AppSettings.currentSchemaVersion,
        appearance: AppearanceSettings = .init(),
        notchBehavior: NotchBehaviorSettings = .init()
    ) {
        self.schemaVersion = schemaVersion
        self.appearance = appearance
        self.notchBehavior = notchBehavior
    }

    public static let safeDefaults = AppSettings()
}

public struct SettingsProjection: Equatable, Sendable {
    public let theme: SettingsTheme
    public let reducedMotion: ReducedMotionOverride
    public let hoverDelay: Duration
    public let autoCollapseTimeout: Duration

    public init(settings: AppSettings) {
        theme = settings.appearance.theme
        reducedMotion = settings.appearance.reducedMotion
        hoverDelay = settings.notchBehavior.hoverDelay.duration
        autoCollapseTimeout = settings.notchBehavior.autoCollapseTimeout.duration
    }
}

public enum SettingsRecoveryOutcome: Equatable, Sendable {
    case loaded
    case recoveredToSafeDefaults
    case readOnlyFutureSchema(version: Int)
    case persistenceFailed
}

public struct SettingsLoadResult: Equatable, Sendable {
    public let settings: AppSettings
    public let recovery: SettingsRecoveryOutcome

    public var projection: SettingsProjection { .init(settings: settings) }
}

public enum SettingsMutation: Sendable {
    case theme(SettingsTheme)
    case reducedMotion(ReducedMotionOverride)
    case hoverDelay(HoverDelay)
    case autoCollapseTimeout(AutoCollapseTimeout)
    case replace(AppSettings)
}

public enum SettingsMutationOutcome: Equatable, Sendable {
    case saved
    case rejected
    case readOnly
    case persistenceFailed
}

public struct SettingsMutationResult: Equatable, Sendable {
    public let settings: AppSettings
    public let outcome: SettingsMutationOutcome

    public var projection: SettingsProjection { .init(settings: settings) }
}

public protocol SettingsProjectionApplying: Sendable {
    func apply(_ projection: SettingsProjection) async
}

/// The only filesystem boundary beneath `SettingsStore`.
public protocol SettingsBackend: Sendable {
    func readActive() async throws -> Data?
    func replaceActive(with data: Data) async throws
    func quarantine(_ data: Data) async throws
}

public enum SettingsStoreError: Error, Equatable, Sendable {
    case invalidSnapshot
    case futureSchema(Int)
    case readOnly
}

public actor SettingsStore {
    private let backend: any SettingsBackend
    private let runtime: (any SettingsProjectionApplying)?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var settings = AppSettings.safeDefaults
    private var recovery: SettingsRecoveryOutcome = .loaded
    private var isLoaded = false
    private var isReadOnly = false

    public init(backend: any SettingsBackend, runtime: (any SettingsProjectionApplying)? = nil) {
        self.backend = backend
        self.runtime = runtime
    }

    public func load() async -> SettingsLoadResult {
        guard !isLoaded else { return .init(settings: settings, recovery: recovery) }
        isLoaded = true

        do {
            guard let data = try await backend.readActive() else {
                try await persist(AppSettings.safeDefaults)
                settings = .safeDefaults
                recovery = .loaded
                await publish()
                return .init(settings: settings, recovery: recovery)
            }

            let decoded = try decode(data)
            switch decoded {
            case .current(let loaded):
                settings = loaded
                recovery = .loaded
                await publish()
            case .migrated(let migrated):
                do {
                    try await persist(migrated)
                    settings = migrated
                    recovery = .loaded
                    await publish()
                } catch {
                    recovery = .persistenceFailed
                }
            case .future(let version):
                isReadOnly = true
                recovery = .readOnlyFutureSchema(version: version)
            }
        } catch {
            await recoverCorruptSnapshot()
        }
        return .init(settings: settings, recovery: recovery)
    }

    public func mutate(_ mutation: SettingsMutation) async -> SettingsMutationResult {
        _ = await load()
        guard !isReadOnly else { return .init(settings: settings, outcome: .readOnly) }
        var candidate = settings
        switch mutation {
        case .theme(let value): candidate.appearance.theme = value
        case .reducedMotion(let value): candidate.appearance.reducedMotion = value
        case .hoverDelay(let value): candidate.notchBehavior.hoverDelay = value
        case .autoCollapseTimeout(let value): candidate.notchBehavior.autoCollapseTimeout = value
        case .replace(let value): candidate = value
        }
        guard candidate.schemaVersion == AppSettings.currentSchemaVersion else {
            return .init(settings: settings, outcome: .rejected)
        }
        do {
            try await persist(candidate)
            settings = candidate
            recovery = .loaded
            await publish()
            return .init(settings: settings, outcome: .saved)
        } catch {
            recovery = .persistenceFailed
            return .init(settings: settings, outcome: .persistenceFailed)
        }
    }

    public func exportSanitized() async throws -> Data {
        _ = await load()
        guard !isReadOnly else { throw SettingsStoreError.readOnly }
        return try encoder.encode(settings)
    }

    public func importSanitized(_ data: Data) async -> SettingsMutationResult {
        _ = await load()
        guard !isReadOnly else { return .init(settings: settings, outcome: .readOnly) }
        guard case .current(let imported)? = try? decode(data) else {
            return .init(settings: settings, outcome: .rejected)
        }
        do {
            try await persist(imported)
            settings = imported
            recovery = .loaded
            await publish()
            return .init(settings: settings, outcome: .saved)
        } catch {
            recovery = .persistenceFailed
            return .init(settings: settings, outcome: .persistenceFailed)
        }
    }

    public func reset(confirmingFutureSchema: Bool = false) async -> SettingsMutationResult {
        _ = await load()
        guard !isReadOnly || confirmingFutureSchema else {
            return .init(settings: settings, outcome: .readOnly)
        }
        do {
            try await persist(.safeDefaults)
            isReadOnly = false
            settings = .safeDefaults
            recovery = .loaded
            await publish()
            return .init(settings: settings, outcome: .saved)
        } catch {
            recovery = .persistenceFailed
            return .init(settings: settings, outcome: .persistenceFailed)
        }
    }

    private func persist(_ candidate: AppSettings) async throws {
        try await backend.replaceActive(with: encoder.encode(candidate))
    }

    private func publish() async {
        await runtime?.apply(.init(settings: settings))
    }

    private func recoverCorruptSnapshot() async {
        do {
            if let bytes = try await backend.readActive() {
                try await backend.quarantine(bytes)
            }
            try await persist(.safeDefaults)
            settings = .safeDefaults
            recovery = .recoveredToSafeDefaults
            await publish()
        } catch {
            recovery = .persistenceFailed
        }
    }

    private enum DecodedSnapshot {
        case current(AppSettings)
        case migrated(AppSettings)
        case future(Int)
    }

    private struct SchemaProbe: Decodable { let schemaVersion: Int }

    private struct LegacySettingsV0: Decodable {
        let schemaVersion: Int
        let theme: SettingsTheme?
        let reducedMotion: ReducedMotionOverride?
        let hoverDelay: HoverDelay?
        let autoCollapseTimeout: AutoCollapseTimeout?
    }

    private func decode(_ data: Data) throws -> DecodedSnapshot {
        let version = try decoder.decode(SchemaProbe.self, from: data).schemaVersion
        if version > AppSettings.currentSchemaVersion { return .future(version) }
        if version == AppSettings.currentSchemaVersion {
            try validateCurrentSchemaFields(in: data)
            let current = try decoder.decode(AppSettings.self, from: data)
            guard current.schemaVersion == AppSettings.currentSchemaVersion else {
                throw SettingsStoreError.invalidSnapshot
            }
            return .current(current)
        }
        guard version == 0 else { throw SettingsStoreError.invalidSnapshot }
        let legacy = try decoder.decode(LegacySettingsV0.self, from: data)
        return .migrated(
            .init(
                appearance: .init(
                    theme: legacy.theme ?? .system,
                    reducedMotion: legacy.reducedMotion ?? .followSystem
                ),
                notchBehavior: .init(
                    hoverDelay: legacy.hoverDelay ?? .milliseconds300,
                    autoCollapseTimeout: legacy.autoCollapseTimeout ?? .seconds3
                )
            )
        )
    }

    private func validateCurrentSchemaFields(in data: Data) throws {
        guard
            let snapshot = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            Set(snapshot.keys) == ["schemaVersion", "appearance", "notchBehavior"],
            let appearance = snapshot["appearance"] as? [String: Any],
            Set(appearance.keys) == ["theme", "reducedMotion"],
            let notchBehavior = snapshot["notchBehavior"] as? [String: Any],
            Set(notchBehavior.keys) == ["hoverDelay", "autoCollapseTimeout"]
        else {
            throw SettingsStoreError.invalidSnapshot
        }
    }
}

/// Application Support backend. Quarantine is bounded to three files of at most one MiB.
public actor FileSettingsBackend: SettingsBackend {
    public static let maximumQuarantineFiles = 3
    public static let maximumQuarantineBytes = 1_048_576

    private let directory: URL
    private let activeURL: URL
    private let quarantineDirectory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        activeURL = directory.appending(path: "settings.json")
        quarantineDirectory = directory.appending(path: "quarantine", directoryHint: .isDirectory)
        self.fileManager = fileManager
    }

    public static func applicationSupport() -> FileSettingsBackend {
        let root = URL(filePath: NSHomeDirectory(), directoryHint: .isDirectory)
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
        return .init(directory: root.appending(path: "NotchHub", directoryHint: .isDirectory))
    }

    public func readActive() throws -> Data? {
        guard fileManager.fileExists(atPath: activeURL.path) else { return nil }
        return try Data(contentsOf: activeURL)
    }

    public func replaceActive(with data: Data) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: activeURL, options: .atomic)
    }

    public func quarantine(_ data: Data) throws {
        guard data.count <= Self.maximumQuarantineBytes else { throw SettingsStoreError.invalidSnapshot }
        try fileManager.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)
        let files = try fileManager.contentsOfDirectory(
            at: quarantineDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let ordered = try files.sorted {
            let left =
                try $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let right =
                try $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return left < right
        }
        for file in ordered.prefix(max(0, ordered.count - Self.maximumQuarantineFiles + 1)) {
            try fileManager.removeItem(at: file)
        }
        let name = "corrupt-\(UUID().uuidString).json"
        try data.write(to: quarantineDirectory.appending(path: name), options: .atomic)
    }
}
