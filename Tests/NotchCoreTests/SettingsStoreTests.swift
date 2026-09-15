import Foundation
import NotchCore
import Testing

@Test("Settings store persists every accepted F6 v2 value across relaunch")
func persistsAcceptedSettingsAcrossRelaunch() async throws {
    let backend = MemorySettingsBackend()
    let store = SettingsStore(backend: backend)

    let initial = await store.load()
    #expect(initial.settings == .safeDefaults)
    #expect(initial.settings.appearance.theme == .system)
    #expect(initial.settings.appearance.reducedMotion == .followSystem)
    #expect(initial.settings.notchBehavior.hoverDelay == .milliseconds300)
    #expect(initial.settings.notchBehavior.autoCollapseTimeout == .seconds3)

    for theme in SettingsTheme.allCases {
        #expect((await store.mutate(.theme(theme))).outcome == .saved)
    }
    for motion in ReducedMotionOverride.allCases {
        #expect((await store.mutate(.reducedMotion(motion))).outcome == .saved)
    }
    for delay in HoverDelay.allCases {
        #expect((await store.mutate(.hoverDelay(delay))).outcome == .saved)
    }
    for timeout in AutoCollapseTimeout.allCases {
        #expect((await store.mutate(.autoCollapseTimeout(timeout))).outcome == .saved)
    }

    let relaunched = SettingsStore(backend: backend)
    let loaded = await relaunched.load()
    #expect(loaded.settings.appearance.theme == .dark)
    #expect(loaded.settings.appearance.reducedMotion == .reduceMotion)
    #expect(loaded.settings.notchBehavior.hoverDelay == .milliseconds500)
    #expect(loaded.settings.notchBehavior.autoCollapseTimeout == .seconds5)
}

@Test("Settings store rejects an invalid replacement without changing last known good settings")
func rejectsInvalidReplacement() async {
    let backend = MemorySettingsBackend()
    let store = SettingsStore(backend: backend)
    _ = await store.load()
    let before = await store.mutate(.theme(.dark))
    let rejected = await store.mutate(.replace(.init(schemaVersion: 99)))

    #expect(rejected.outcome == .rejected)
    #expect(rejected.settings == before.settings)
}

@Test("Settings store migrates released v0 snapshot deterministically before activation")
func migratesLegacySnapshot() async throws {
    let legacy = try JSONSerialization.data(
        withJSONObject: [
            "schemaVersion": 0,
            "theme": "light",
            "reducedMotion": "reduceMotion",
            "hoverDelay": 150,
            "autoCollapseTimeout": 2,
        ]
    )
    let backend = MemorySettingsBackend(active: legacy)
    let result = await SettingsStore(backend: backend).load()

    #expect(result.recovery == .loaded)
    #expect(
        result.settings
            == .init(
                appearance: .init(theme: .light, reducedMotion: .reduceMotion),
                notchBehavior: .init(hoverDelay: .milliseconds150, autoCollapseTimeout: .seconds2)
            ))
    #expect(try JSONDecoder().decode(AppSettings.self, from: #require(await backend.active)) == result.settings)
}

@Test("A failed migration write preserves the valid legacy snapshot")
func preservesLegacySnapshotWhenMigrationWriteFails() async throws {
    let legacy = try JSONSerialization.data(withJSONObject: ["schemaVersion": 0, "theme": "light"])
    let backend = MemorySettingsBackend(active: legacy, shouldFailWrites: true)
    let result = await SettingsStore(backend: backend).load()

    #expect(result.recovery == .persistenceFailed)
    #expect(await backend.active == legacy)
    #expect(await backend.quarantined.isEmpty)
}

@Test("Settings store migrates a released F4 v1 snapshot with empty shortcut bindings")
func migratesF4SnapshotToShortcutSchema() async throws {
    let v1 = try JSONSerialization.data(
        withJSONObject: [
            "schemaVersion": 1,
            "appearance": ["theme": "dark", "reducedMotion": "followSystem"],
            "notchBehavior": ["hoverDelay": 300, "autoCollapseTimeout": 3],
        ]
    )

    let result = await SettingsStore(backend: MemorySettingsBackend(active: v1)).load()

    #expect(result.recovery == .loaded)
    #expect(result.settings.schemaVersion == AppSettings.currentSchemaVersion)
    #expect(result.settings.shortcuts.bindings.isEmpty)
}

@Test("Settings store publishes the complete valid runtime projection")
func publishesCompleteRuntimeProjection() async {
    let runtime = RecordingRuntime()
    let store = SettingsStore(backend: MemorySettingsBackend(), runtime: runtime)
    _ = await store.load()
    _ = await store.mutate(.theme(.dark))
    _ = await store.mutate(.reducedMotion(.reduceMotion))
    _ = await store.mutate(.hoverDelay(.milliseconds150))
    _ = await store.mutate(.autoCollapseTimeout(.seconds2))

    #expect(
        await runtime.latest
            == .init(
                settings: .init(
                    appearance: .init(theme: .dark, reducedMotion: .reduceMotion),
                    notchBehavior: .init(hoverDelay: .milliseconds150, autoCollapseTimeout: .seconds2)
                )
            )
    )
}

@Test("Corrupt current snapshot is quarantined and recovers with safe defaults")
func quarantinesCorruptSnapshot() async throws {
    let corrupt = Data("{not-json".utf8)
    let backend = MemorySettingsBackend(active: corrupt)
    let result = await SettingsStore(backend: backend).load()

    #expect(result.recovery == .recoveredToSafeDefaults)
    #expect(result.settings == .safeDefaults)
    #expect(await backend.quarantined == [corrupt])
}

@Test("Future schema is read-only and original bytes remain untouched")
func preservesFutureSchema() async throws {
    let future = try JSONSerialization.data(withJSONObject: ["schemaVersion": 3, "future": true])
    let backend = MemorySettingsBackend(active: future)
    let store = SettingsStore(backend: backend)
    let loaded = await store.load()
    let mutation = await store.mutate(.theme(.dark))

    #expect(loaded.recovery == .readOnlyFutureSchema(version: 3))
    #expect(mutation.outcome == .readOnly)
    #expect(await backend.active == future)
    #expect(await backend.quarantined.isEmpty)
}

@Test("Failed atomic replacement retains last known good settings and reports recovery")
func retainsLastKnownGoodOnWriteFailure() async {
    let backend = MemorySettingsBackend()
    let store = SettingsStore(backend: backend)
    _ = await store.load()
    _ = await store.mutate(.theme(.light))
    await backend.failWrites()
    let result = await store.mutate(.theme(.dark))

    #expect(result.outcome == .persistenceFailed)
    #expect(result.settings.appearance.theme == .light)
}

@Test("Invalid import changes nothing and valid import replaces the complete F4 snapshot")
func importsAtomically() async throws {
    let backend = MemorySettingsBackend()
    let store = SettingsStore(backend: backend)
    _ = await store.load()
    _ = await store.mutate(.theme(.dark))
    let invalid = await store.importSanitized(Data("bad".utf8))
    #expect(invalid.outcome == .rejected)
    #expect(invalid.settings.appearance.theme == .dark)

    let imported = AppSettings(
        appearance: .init(theme: .light, reducedMotion: .reduceMotion),
        notchBehavior: .init(hoverDelay: .milliseconds150, autoCollapseTimeout: .seconds2)
    )
    let valid = await store.importSanitized(try JSONEncoder().encode(imported))
    #expect(valid.outcome == .saved)
    #expect(valid.settings == imported)
}

@Test("Export contains exactly the non-secret settings snapshot")
func exportsOnlyF4Settings() async throws {
    let store = SettingsStore(backend: MemorySettingsBackend())
    _ = await store.load()
    _ = await store.mutate(.theme(.dark))

    let exported = try await store.exportSanitized()
    let object = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])

    #expect(Set(object.keys) == ["schemaVersion", "appearance", "notchBehavior", "shortcuts"])
    #expect((object["appearance"] as? [String: String])?["theme"] == "dark")
}

@Test("Import rejects non-F4 scope without replacing last known good settings")
func rejectsImportWithUnknownScope() async throws {
    let backend = MemorySettingsBackend()
    let store = SettingsStore(backend: backend)
    _ = await store.load()
    let before = await store.mutate(.theme(.dark))
    let imported = try JSONSerialization.data(
        withJSONObject: [
            "schemaVersion": 1,
            "appearance": ["theme": "light", "reducedMotion": "reduceMotion"],
            "notchBehavior": ["hoverDelay": 150, "autoCollapseTimeout": 2],
            "credential": "must-not-import",
        ]
    )

    let result = await store.importSanitized(imported)

    #expect(result.outcome == .rejected)
    #expect(result.settings == before.settings)
    #expect(try JSONDecoder().decode(AppSettings.self, from: #require(await backend.active)) == before.settings)
}

@Test("Import rejects shortcut bindings with a duplicate enabled chord")
func rejectsDuplicateShortcutChordOnImport() async throws {
    let store = SettingsStore(backend: MemorySettingsBackend())
    _ = await store.load()
    let duplicate = try JSONSerialization.data(
        withJSONObject: [
            "schemaVersion": AppSettings.currentSchemaVersion,
            "appearance": ["theme": "system", "reducedMotion": "followSystem"],
            "notchBehavior": ["hoverDelay": 300, "autoCollapseTimeout": 3],
            "shortcuts": [
                "bindings": [
                    ["actionID": "app.openSettings", "key": "s", "modifiers": ["command"], "isEnabled": true],
                    ["actionID": "app.openDiagnostics", "key": "s", "modifiers": ["command"], "isEnabled": true],
                ]
            ],
        ]
    )

    #expect((await store.importSanitized(duplicate)).outcome == .rejected)
}

@Test("A failed import replacement retains last known good settings")
func retainsLastKnownGoodOnImportWriteFailure() async throws {
    let backend = MemorySettingsBackend()
    let store = SettingsStore(backend: backend)
    _ = await store.load()
    let before = await store.mutate(.theme(.dark))
    await backend.failWrites()

    let result = await store.importSanitized(try JSONEncoder().encode(AppSettings.safeDefaults))

    #expect(result.outcome == .persistenceFailed)
    #expect(result.settings == before.settings)
    #expect(try JSONDecoder().decode(AppSettings.self, from: #require(await backend.active)) == before.settings)
}

@Test("Normal reset replaces the settings snapshot with safe defaults")
func normalResetRestoresF4Defaults() async throws {
    let store = SettingsStore(backend: MemorySettingsBackend())
    _ = await store.load()
    _ = await store.mutate(.theme(.dark))
    _ = await store.mutate(.hoverDelay(.milliseconds150))

    let reset = await store.reset()
    let exported = try await store.exportSanitized()
    let object = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])

    #expect(reset.outcome == .saved)
    #expect(reset.settings == .safeDefaults)
    #expect(Set(object.keys) == ["schemaVersion", "appearance", "notchBehavior", "shortcuts"])
}

@Test("File backend rotates corrupt snapshots at the documented three-file one-MiB limit")
func rotatesQuarantine() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let backend = FileSettingsBackend(directory: directory)

    for value in 0..<4 {
        try await backend.quarantine(Data("corrupt-\(value)".utf8))
    }

    let quarantine = directory.appending(path: "quarantine", directoryHint: .isDirectory)
    let files = try FileManager.default.contentsOfDirectory(at: quarantine, includingPropertiesForKeys: [.fileSizeKey])
    #expect(files.count == FileSettingsBackend.maximumQuarantineFiles)
    for file in files {
        #expect(
            try file.resourceValues(forKeys: [.fileSizeKey]).fileSize! <= FileSettingsBackend.maximumQuarantineBytes)
    }
}

private actor MemorySettingsBackend: SettingsBackend {
    var active: Data?
    var quarantined: [Data] = []
    private var shouldFailWrites: Bool

    init(active: Data? = nil, shouldFailWrites: Bool = false) {
        self.active = active
        self.shouldFailWrites = shouldFailWrites
    }

    func readActive() throws -> Data? { active }

    func replaceActive(with data: Data) throws {
        if shouldFailWrites { throw SettingsStoreError.invalidSnapshot }
        active = data
    }

    func quarantine(_ data: Data) throws { quarantined.append(data) }

    func failWrites() { shouldFailWrites = true }
}

private actor RecordingRuntime: SettingsProjectionApplying {
    var latest: SettingsProjection?

    func apply(_ projection: SettingsProjection) { latest = projection }
}
