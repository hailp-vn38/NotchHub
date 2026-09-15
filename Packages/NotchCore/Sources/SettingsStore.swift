import Foundation
import NotchDomain

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

public struct ShortcutSettings: Codable, Equatable, Sendable {
    public var bindings: [ShortcutBinding]

    public init(bindings: [ShortcutBinding] = []) {
        self.bindings = bindings
    }

    public var isValid: Bool {
        bindings.enumerated().allSatisfy { index, binding in
            binding.isValid
                && !bindings[..<index].contains(where: { existing in
                    existing.actionID == binding.actionID
                        || (existing.isEnabled && binding.isEnabled
                            && existing.key == binding.key && existing.modifiers == binding.modifiers)
                })
        }
    }
}

public struct ModuleEnablementSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var xiaozhi: XiaozhiSettings?

    public init(isEnabled: Bool = true, xiaozhi: XiaozhiSettings? = nil) {
        self.isEnabled = isEnabled
        self.xiaozhi = xiaozhi
    }
}

public enum XiaozhiConversationMode: String, Codable, CaseIterable, Sendable { case auto, pushToTalk }

public enum XiaozhiIdentity {
    public static let clientID = "test-client"
    public static let defaultDeviceID = randomDeviceID()

    public static func randomDeviceID() -> String {
        var generator = SystemRandomNumberGenerator()
        var bytes = (0..<6).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        bytes[0] = (bytes[0] & 0b1111_1100) | 0b0000_0010
        return bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    public static func isValidDeviceID(_ value: String) -> Bool {
        guard
            value.range(of: "^[0-9A-F]{2}(:[0-9A-F]{2}){5}$", options: .regularExpression) != nil,
            let firstOctet = UInt8(value.prefix(2), radix: 16)
        else { return false }
        return firstOctet & 0b0000_0011 == 0b0000_0010
    }
}

public struct XiaozhiSettings: Codable, Equatable, Sendable {
    public var isPreparedOnLaunch: Bool
    public var autoReconnect: Bool
    public var conversationMode: XiaozhiConversationMode

    public init(
        isPreparedOnLaunch: Bool = true,
        autoReconnect: Bool = true,
        conversationMode: XiaozhiConversationMode = .auto
    ) {
        self.isPreparedOnLaunch = isPreparedOnLaunch
        self.autoReconnect = autoReconnect
        self.conversationMode = conversationMode
    }
}

/// The complete, non-secret settings snapshot; F6 v2 adds shortcut bindings.
public struct AppSettings: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 5

    public var schemaVersion: Int
    public var appearance: AppearanceSettings
    public var notchBehavior: NotchBehaviorSettings
    public var shortcuts: ShortcutSettings
    public var modules: [String: ModuleEnablementSettings]

    public init(
        schemaVersion: Int = AppSettings.currentSchemaVersion,
        appearance: AppearanceSettings = .init(),
        notchBehavior: NotchBehaviorSettings = .init(),
        shortcuts: ShortcutSettings = .init(),
        modules: [String: ModuleEnablementSettings] = ["demo": .init()]
    ) {
        self.schemaVersion = schemaVersion
        self.appearance = appearance
        self.notchBehavior = notchBehavior
        self.shortcuts = shortcuts
        self.modules = modules
    }

    /// Namespaced non-secret module settings. Identity stays in Keychain.
    public var xiaozhi: XiaozhiSettings {
        get { modules["xiaozhi"]?.xiaozhi ?? .init() }
        set {
            var entry = modules["xiaozhi"] ?? .init(isEnabled: false)
            entry.xiaozhi = newValue
            modules["xiaozhi"] = entry
        }
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
    case shortcutBindings([ShortcutBinding])
    case moduleEnabled(Bool, id: ModuleID)
    case xiaozhi(XiaozhiSettings)
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
        case .shortcutBindings(let value): candidate.shortcuts.bindings = value
        case .moduleEnabled(let value, let id): candidate.modules[id.rawValue] = .init(isEnabled: value)
        case .xiaozhi(let value): candidate.xiaozhi = value
        case .replace(let value): candidate = value
        }
        guard candidate.schemaVersion == AppSettings.currentSchemaVersion,
            candidate.shortcuts.isValid
        else {
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
            guard current.schemaVersion == AppSettings.currentSchemaVersion, current.shortcuts.isValid else {
                throw SettingsStoreError.invalidSnapshot
            }
            return .current(current)
        }
        if version == 4 {
            let legacy = try decoder.decode(LegacySettingsV4.self, from: data)
            var migrated = AppSettings(
                appearance: legacy.appearance, notchBehavior: legacy.notchBehavior,
                shortcuts: legacy.shortcuts, modules: legacy.modules)
            migrated.xiaozhi = legacy.xiaozhi
            return .migrated(migrated)
        }
        if version == 3 {
            let legacy = try decoder.decode(LegacySettingsV3.self, from: data)
            var migrated = AppSettings(
                appearance: legacy.appearance, notchBehavior: legacy.notchBehavior,
                shortcuts: legacy.shortcuts, modules: legacy.modules)
            migrated.xiaozhi = .init()
            return .migrated(migrated)
        }
        if version == 2 {
            let legacy = try decoder.decode(LegacySettingsV2.self, from: data)
            return .migrated(
                .init(appearance: legacy.appearance, notchBehavior: legacy.notchBehavior, shortcuts: legacy.shortcuts))
        }
        if version == 1 {
            let legacy = try decoder.decode(LegacySettingsV1.self, from: data)
            return .migrated(
                .init(
                    appearance: legacy.appearance,
                    notchBehavior: legacy.notchBehavior
                )
            )
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
            Set(snapshot.keys) == ["schemaVersion", "appearance", "notchBehavior", "shortcuts", "modules"],
            let appearance = snapshot["appearance"] as? [String: Any],
            Set(appearance.keys) == ["theme", "reducedMotion"],
            let notchBehavior = snapshot["notchBehavior"] as? [String: Any],
            Set(notchBehavior.keys) == ["hoverDelay", "autoCollapseTimeout"],
            let shortcuts = snapshot["shortcuts"] as? [String: Any],
            Set(shortcuts.keys) == ["bindings"],
            let modules = snapshot["modules"] as? [String: Any],
            modules["demo"] as? [String: Any] != nil
        else {
            throw SettingsStoreError.invalidSnapshot
        }
    }

    private struct LegacySettingsV1: Decodable {
        let schemaVersion: Int
        let appearance: AppearanceSettings
        let notchBehavior: NotchBehaviorSettings
    }

    private struct LegacySettingsV2: Decodable {
        let schemaVersion: Int
        let appearance: AppearanceSettings
        let notchBehavior: NotchBehaviorSettings
        let shortcuts: ShortcutSettings
    }

    private struct LegacySettingsV3: Decodable {
        let schemaVersion: Int
        let appearance: AppearanceSettings
        let notchBehavior: NotchBehaviorSettings
        let shortcuts: ShortcutSettings
        let modules: [String: ModuleEnablementSettings]
    }

    private struct LegacySettingsV4: Decodable {
        let schemaVersion: Int
        let appearance: AppearanceSettings
        let notchBehavior: NotchBehaviorSettings
        let shortcuts: ShortcutSettings
        let modules: [String: ModuleEnablementSettings]
        let xiaozhi: XiaozhiSettings
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
