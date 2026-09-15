import Foundation
import NotchActions
import NotchCore
import NotchDomain
import Observation
import SwiftUI
import UniformTypeIdentifiers

public enum SettingsRoute: String, CaseIterable, Hashable, Identifiable, Sendable {
    case general
    case appearance
    case notchBehavior
    case shortcuts
    case permissions
    case actions
    case modules
    case diagnostics
    case about

    public var id: Self { self }

    public var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .notchBehavior: "Notch Behavior"
        case .shortcuts: "Shortcuts"
        case .permissions: "Permissions"
        case .actions: "Actions"
        case .modules: "Modules"
        case .diagnostics: "Diagnostics"
        case .about: "About"
        }
    }

    public var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .notchBehavior: "macbook"
        case .shortcuts: "keyboard"
        case .permissions: "lock.shield"
        case .actions: "bolt"
        case .modules: "square.grid.2x2"
        case .diagnostics: "waveform.path.ecg"
        case .about: "info.circle"
        }
    }
}

public enum SettingsOwningPhase: String, Equatable, Sendable {
    case f3
    case f4
    case f5
    case f6
    case f7
    case f8
    case f9

    public var displayName: String { rawValue.uppercased() }
}

public struct SettingsRouteState: Equatable, Sendable {
    public let route: SettingsRoute
    public let owningPhase: SettingsOwningPhase
    public let isInteractive: Bool

    public init(route: SettingsRoute, owningPhase: SettingsOwningPhase, isInteractive: Bool) {
        self.route = route
        self.owningPhase = owningPhase
        self.isInteractive = isInteractive
    }
}

public enum SettingsMotionPreference: String, CaseIterable, Equatable, Sendable {
    case system
    case reduced

    public var title: String {
        switch self {
        case .system: "Follow System"
        case .reduced: "Reduce Motion"
        }
    }
}

public enum SettingsShellOutcome: Equatable, Sendable {
    case appliedSessionOnly
    case unavailable(owner: SettingsOwningPhase)
}

@MainActor
@Observable
public final class SettingsShellModel {
    public let routes = SettingsRoute.allCases
    public fileprivate(set) var selectedRoute: SettingsRoute
    public private(set) var sessionMotionPreference: SettingsMotionPreference = .system
    public private(set) var settings = AppSettings.safeDefaults
    public private(set) var recoveryOutcome: SettingsRecoveryOutcome = .loaded
    public private(set) var saveOutcome: SettingsMutationOutcome?
    fileprivate let settingsStore: SettingsStore?
    public let permissionCenter: PermissionCenterModel?
    public let shortcutPresentation: ShortcutPresentationModel?
    public let moduleRuntime: ModuleRuntime?
    public private(set) var moduleHealth: [ModuleHealth] = []

    public init(
        selectedRoute: SettingsRoute = .general,
        settingsStore: SettingsStore? = nil,
        permissionCenter: PermissionCenterModel? = nil,
        shortcutPresentation: ShortcutPresentationModel? = nil,
        moduleRuntime: ModuleRuntime? = nil
    ) {
        self.selectedRoute = selectedRoute
        self.settingsStore = settingsStore
        self.permissionCenter = permissionCenter
        self.shortcutPresentation = shortcutPresentation
        self.moduleRuntime = moduleRuntime
    }

    public func select(_ route: SettingsRoute) {
        selectedRoute = route
    }

    public func routeState(for route: SettingsRoute) -> SettingsRouteState {
        switch route {
        case .general, .appearance, .notchBehavior:
            .init(route: route, owningPhase: .f4, isInteractive: true)
        case .about:
            .init(route: route, owningPhase: .f3, isInteractive: true)
        case .shortcuts:
            .init(route: route, owningPhase: .f6, isInteractive: shortcutPresentation != nil)
        case .actions:
            .init(route: route, owningPhase: .f6, isInteractive: false)
        case .permissions:
            .init(route: route, owningPhase: .f5, isInteractive: permissionCenter != nil)
        case .modules:
            .init(route: route, owningPhase: .f7, isInteractive: moduleRuntime != nil)
        case .diagnostics:
            .init(route: route, owningPhase: .f9, isInteractive: false)
        }
    }

    public func setSessionMotionPreference(_ preference: SettingsMotionPreference) -> SettingsShellOutcome {
        guard selectedRoute == .appearance else {
            return .unavailable(owner: routeState(for: selectedRoute).owningPhase)
        }
        sessionMotionPreference = preference
        return .appliedSessionOnly
    }

    public func resetSessionPreview() {
        sessionMotionPreference = .system
    }

    public func isReducedMotion(systemPreference: Bool) -> Bool {
        systemPreference
            || (settingsStore == nil
                ? sessionMotionPreference == .reduced
                : settings.appearance.reducedMotion == .reduceMotion)
    }

    public func loadSettings() async {
        guard let settingsStore else { return }
        let result = await settingsStore.load()
        settings = result.settings
        recoveryOutcome = result.recovery
        await shortcutPresentation?.load()
        await loadModuleHealth()
    }

    public func loadModuleHealth() async {
        moduleHealth = await moduleRuntime?.healthSnapshot() ?? []
    }

    public func setModuleEnabled(_ enabled: Bool, id: ModuleID) {
        guard let moduleRuntime else { return }
        Task { [weak self] in
            await moduleRuntime.setEnabled(enabled, for: id)
            await self?.loadModuleHealth()
        }
    }

    public func restartModule(id: ModuleID) {
        guard let moduleRuntime else { return }
        Task { [weak self] in
            await moduleRuntime.restart(id)
            await self?.loadModuleHealth()
        }
    }

    public func update(_ mutation: SettingsMutation) {
        guard let settingsStore else { return }
        Task { [weak self] in
            let result = await settingsStore.mutate(mutation)
            self?.apply(result)
        }
    }

    public func resetSettings() {
        resetSettings(confirmingFutureSchema: false)
    }

    public func resetSettings(confirmingFutureSchema: Bool) {
        guard let settingsStore else { return }
        Task { [weak self] in
            self?.apply(await settingsStore.reset(confirmingFutureSchema: confirmingFutureSchema))
        }
    }

    public func importSettings(_ data: Data) {
        guard let settingsStore else { return }
        Task { [weak self] in
            self?.apply(await settingsStore.importSanitized(data))
        }
    }

    public func exportSettings() async -> Data? {
        guard let settingsStore else { return nil }
        return try? await settingsStore.exportSanitized()
    }

    public var isReadOnly: Bool {
        if case .readOnlyFutureSchema = recoveryOutcome { return true }
        return false
    }

    public var preferredColorScheme: ColorScheme? {
        switch settings.appearance.theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private func apply(_ result: SettingsMutationResult) {
        settings = result.settings
        saveOutcome = result.outcome
    }
}

public enum NotchUITokens {
    public static let microSpacing: CGFloat = 4
    public static let controlSpacing: CGFloat = 8
    public static let rowSpacing: CGFloat = 12
    public static let sectionSpacing: CGFloat = 16
    public static let contentPadding: CGFloat = 20
    public static let majorSpacing: CGFloat = 24
    public static let cardCornerRadius: CGFloat = 12
    public static let contentPrimary = Color.primary
    public static let contentSecondary = Color.secondary
    public static let statusWarning = Color.orange
    public static let applicationMaterial: Material = .regularMaterial
    public static let pageTitle = Font.title2.bold()
    public static let sectionTitle = Font.headline
}

public struct SettingsShellView: View {
    @Bindable private var model: SettingsShellModel
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion

    public init(model: SettingsShellModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedRoute) {
                ForEach(model.routes) { route in
                    Label(route.title, systemImage: route.symbolName)
                        .tag(route)
                }
            }
            .accessibilityLabel("Settings sections")
        } detail: {
            SettingsPageView(model: model, systemReducedMotion: systemReducedMotion)
        }
        .navigationSplitViewStyle(.balanced)
        .task { await model.loadSettings() }
        .preferredColorScheme(model.preferredColorScheme)
        .frame(minWidth: 760, minHeight: 560)
    }
}

private struct SettingsPageView: View {
    @Bindable var model: SettingsShellModel
    let systemReducedMotion: Bool
    @State private var isImporting = false
    @State private var exportDocument: SettingsExportDocument?
    @State private var isConfirmingFutureReset = false

    var body: some View {
        let route = model.selectedRoute
        let state = model.routeState(for: route)
        ScrollView {
            VStack(alignment: .leading, spacing: NotchUITokens.sectionSpacing) {
                VStack(alignment: .leading, spacing: NotchUITokens.microSpacing) {
                    Text(route.title).font(NotchUITokens.pageTitle)
                    Text(subtitle(for: route)).foregroundStyle(NotchUITokens.contentSecondary)
                }

                if state.isInteractive {
                    interactiveContent(for: route)
                } else {
                    SettingsUnavailableState(owner: state.owningPhase)
                }
                SettingsFeedback(recovery: model.recoveryOutcome, save: model.saveOutcome)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(NotchUITokens.contentPadding)
        }
        .accessibilityElement(children: .contain)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            model.importSettings(data)
        }
        .fileExporter(
            isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
            document: exportDocument,
            contentType: .json,
            defaultFilename: "NotchHub-settings"
        ) { _ in }
        .confirmationDialog(
            "Discard newer settings?",
            isPresented: $isConfirmingFutureReset,
            titleVisibility: .visible
        ) {
            Button("Discard and reset", role: .destructive) {
                model.resetSettings(confirmingFutureSchema: true)
            }
        } message: {
            Text("This replaces the newer snapshot with safe F4 defaults.")
        }
    }

    @ViewBuilder
    private func interactiveContent(for route: SettingsRoute) -> some View {
        switch route {
        case .appearance:
            SettingsSection(title: "Appearance") {
                Picker(
                    "Theme",
                    selection: Binding(
                        get: { model.settings.appearance.theme },
                        set: { model.update(.theme($0)) }
                    )
                ) {
                    ForEach(SettingsTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }
            }
            SettingsSection(title: "Motion") {
                Picker(
                    "Motion preference",
                    selection: Binding(
                        get: {
                            model.settingsStore == nil
                                ? model.sessionMotionPreference
                                : model.settings.appearance.reducedMotion == .reduceMotion ? .reduced : .system
                        },
                        set: {
                            if model.settingsStore == nil {
                                _ = model.setSessionMotionPreference($0)
                            } else {
                                model.update(.reducedMotion($0 == .reduced ? .reduceMotion : .followSystem))
                            }
                        }
                    )
                ) {
                    ForEach(SettingsMotionPreference.allCases, id: \.self) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
                Text(
                    model.settingsStore == nil
                        ? "This preview applies only while NotchHub is running and is not saved."
                        : "Saved changes apply safely while NotchHub is running."
                )
                .font(.caption)
                .foregroundStyle(NotchUITokens.contentSecondary)
            }
        case .notchBehavior:
            SettingsSection(title: "Current surface behavior") {
                Picker(
                    "Hover delay",
                    selection: Binding(
                        get: { model.settings.notchBehavior.hoverDelay },
                        set: { model.update(.hoverDelay($0)) }
                    )
                ) {
                    ForEach(HoverDelay.allCases, id: \.self) { delay in
                        Text("\(delay.rawValue) ms").tag(delay)
                    }
                }
                Picker(
                    "Auto-collapse",
                    selection: Binding(
                        get: { model.settings.notchBehavior.autoCollapseTimeout },
                        set: { model.update(.autoCollapseTimeout($0)) }
                    )
                ) {
                    ForEach(AutoCollapseTimeout.allCases, id: \.self) { timeout in
                        Text("\(timeout.rawValue) seconds").tag(timeout)
                    }
                }
                Text("Full-screen suppression remains a safety invariant, not a preference.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .general:
            SettingsSection(title: "Foundation") {
                Text(
                    "Appearance and Notch Behavior are stored locally. Import and export contain only this non-secret F4 snapshot."
                )
                Button("Reset Appearance and Notch Behavior", role: .destructive) {
                    if model.isReadOnly {
                        isConfirmingFutureReset = true
                    } else {
                        model.resetSettings()
                    }
                }
                Button("Import Settings…") { isImporting = true }
                    .disabled(model.isReadOnly)
                Button("Export Settings…") {
                    Task { exportDocument = await model.exportSettings().map(SettingsExportDocument.init) }
                }
                .disabled(model.isReadOnly)
            }
        case .about:
            SettingsSection(title: "NotchHub") {
                SettingsStatusRow(title: "Foundation phase", value: "F3 Settings shell")
                SettingsStatusRow(
                    title: "Version",
                    value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                        as? String ?? "Development"
                )
                SettingsStatusRow(title: "License", value: "See repository")
                Text("A local-first macOS platform for glanceable status and quick actions.")
                    .foregroundStyle(NotchUITokens.contentSecondary)
            }
        case .permissions:
            if let permissionCenter = model.permissionCenter {
                PermissionCenterPage(model: permissionCenter)
            }
        case .shortcuts:
            if let shortcutPresentation = model.shortcutPresentation {
                ShortcutSettingsPage(model: shortcutPresentation)
            }
        case .modules:
            ModuleSettingsPage(model: model)
        case .actions, .diagnostics:
            EmptyView()
        }
    }

    private func subtitle(for route: SettingsRoute) -> String {
        switch route {
        case .general: "Application information and the current foundation boundary."
        case .appearance: "Preview visual behavior without saving a preference."
        case .notchBehavior: "Explain the current safe surface defaults."
        case .shortcuts: "Shortcut bindings are ready; Action registration remains future work."
        case .permissions: "Permission Center arrives in F5."
        case .actions: "Registered actions arrive in F6."
        case .modules: "Module runtime arrives in F7."
        case .diagnostics: "Operational diagnostics arrive in F9."
        case .about: "Application information safe to show in the foundation."
        }
    }
}

private struct ModuleSettingsPage: View {
    @Bindable var model: SettingsShellModel

    var body: some View {
        SettingsSection(title: "Modules") {
            if model.moduleHealth.isEmpty {
                Text("No Debug modules are registered.")
            }
            ForEach(model.moduleHealth) { health in
                VStack(alignment: .leading, spacing: NotchUITokens.microSpacing) {
                    Text(health.id.rawValue).font(.headline)
                    Text("\(health.isEnabled ? "Enabled" : "Disabled") — \(health.state.rawValue)")
                        .accessibilityLabel(
                            "\(health.id.rawValue) \(health.isEnabled ? "enabled" : "disabled") \(health.state.rawValue)"
                        )
                    if let error = health.lastError { Text(error).foregroundStyle(.red) }
                    HStack {
                        Button(health.isEnabled ? "Disable" : "Enable") {
                            model.setModuleEnabled(!health.isEnabled, id: health.id)
                        }
                        Button("Restart") { model.restartModule(id: health.id) }
                            .disabled(!health.isEnabled || health.state == .registered || health.state == .stopped)
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
        SettingsSection(title: "Native Xiaozhi Client") {
            Toggle(
                "Prepare Xiaozhi at launch",
                isOn: Binding(
                    get: { model.settings.xiaozhi.isPreparedOnLaunch },
                    set: { value in
                        var settings = model.settings.xiaozhi
                        settings.isPreparedOnLaunch = value
                        model.update(.xiaozhi(settings))
                    }
                )
            )
            Toggle(
                "Reconnect automatically",
                isOn: Binding(
                    get: { model.settings.xiaozhi.autoReconnect },
                    set: { value in
                        var settings = model.settings.xiaozhi
                        settings.autoReconnect = value
                        model.update(.xiaozhi(settings))
                    }
                )
            )
            Toggle(
                "Mute Xiaozhi TTS",
                isOn: Binding(
                    get: { model.settings.xiaozhi.ttsMuted },
                    set: { value in
                        var settings = model.settings.xiaozhi
                        settings.ttsMuted = value
                        model.update(.xiaozhi(settings))
                    }
                )
            )
            Picker(
                "Conversation mode",
                selection: Binding(
                    get: { model.settings.xiaozhi.conversationMode },
                    set: { value in
                        var settings = model.settings.xiaozhi
                        settings.conversationMode = value
                        model.update(.xiaozhi(settings))
                    }
                )
            ) {
                Text("Auto").tag(XiaozhiConversationMode.auto)
                Text("Push-to-Talk").tag(XiaozhiConversationMode.pushToTalk)
            }
            Text("Device identity and credentials are stored separately in Keychain and are never exported.")
                .font(.caption)
                .foregroundStyle(NotchUITokens.contentSecondary)
        }
    }
}

private struct ShortcutSettingsPage: View {
    @Bindable var model: ShortcutPresentationModel

    var body: some View {
        SettingsSection(title: "Keyboard shortcuts") {
            Text("Shortcut bindings are ready for future app-active actions. No keyboard input is captured yet.")
                .font(.caption)
                .foregroundStyle(NotchUITokens.contentSecondary)
            if let feedback = model.feedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(NotchUITokens.statusWarning)
            }
            switch model.state {
            case .empty:
                Text("No shortcut-capable actions are available yet.")
            case .unavailable(let bindings, let disabled):
                unavailableBindings(bindings)
                disabledBindings(disabled)
            case .available(let bindings, let unavailable, let disabled):
                ForEach(bindings, id: \.actionID) { binding in
                    bindingRow(binding, status: "Available")
                }
                unavailableBindings(unavailable)
                disabledBindings(disabled)
            }
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private func unavailableBindings(_ bindings: [ShortcutBinding]) -> some View {
        ForEach(bindings, id: \.actionID) { binding in
            bindingRow(binding, status: "Action unavailable")
        }
    }

    @ViewBuilder
    private func disabledBindings(_ bindings: [ShortcutBinding]) -> some View {
        ForEach(bindings, id: \.actionID) { binding in
            bindingRow(binding, status: "Disabled")
        }
    }

    private func bindingRow(_ binding: ShortcutBinding, status: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(binding.actionID.rawValue)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(NotchUITokens.contentSecondary)
            }
            Spacer()
            Button(binding.isEnabled ? "Disable" : "Enable") {
                Task { await model.setEnabled(!binding.isEnabled, for: binding.actionID) }
            }
            Button("Clear", role: .destructive) {
                Task { await model.clearBinding(for: binding.actionID) }
            }
        }
    }
}

private struct PermissionCenterPage: View {
    @Bindable var model: PermissionCenterModel

    var body: some View {
        SettingsSection(title: "Permission Center") {
            HStack(alignment: .top, spacing: NotchUITokens.rowSpacing) {
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: NotchUITokens.microSpacing) {
                    Text("Recovery notifications").font(.headline)
                    Text("Permission Center only")
                        .font(.subheadline)
                        .foregroundStyle(NotchUITokens.contentSecondary)
                }
                Spacer()
                PermissionStatusBadge(status: model.notificationsStatus, text: statusText)
            }
            Divider()
            PermissionDetailRow(title: "Why", detail: model.notificationsGuidance.reason)
            PermissionDetailRow(title: "Privacy", detail: model.notificationsGuidance.dataImplication)
            Text(model.notificationsGuidance.declineEffect)
                .font(.caption)
                .foregroundStyle(NotchUITokens.contentSecondary)
            permissionAction
        }
        SettingsSection(title: "Native Xiaozhi Client") {
            HStack(alignment: .top, spacing: NotchUITokens.rowSpacing) {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.purple.gradient, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: NotchUITokens.microSpacing) {
                    Text("Microphone").font(.headline)
                    Text("Only requested after you choose to start Xiaozhi voice")
                        .font(.subheadline)
                        .foregroundStyle(NotchUITokens.contentSecondary)
                }
                Spacer()
                PermissionStatusBadge(status: model.microphoneStatus, text: microphoneStatusText)
            }
            Divider()
            PermissionDetailRow(title: "Why", detail: model.microphoneGuidance.reason)
            PermissionDetailRow(title: "Privacy", detail: model.microphoneGuidance.dataImplication)
            Text(model.microphoneGuidance.declineEffect)
                .font(.caption)
                .foregroundStyle(NotchUITokens.contentSecondary)
            microphoneAction
        }
        SettingsSection(title: "Not used by enabled features") {
            Text("NotchHub will not request these permissions until an enabled feature needs them.")
                .font(.caption)
                .foregroundStyle(NotchUITokens.contentSecondary)
            ForEach(model.informationalCapabilities, id: \.self) { capability in
                SettingsStatusRow(title: capability.title, value: "Not used")
            }
        }
        .task { await model.load() }
        .confirmationDialog(
            "Use notifications for Permission Center recovery?",
            isPresented: Binding(
                get: { model.isShowingExplanation },
                set: { if !$0 { model.dismissExplanation() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Enable") {
                Task { await model.confirmNotificationsRecoveryOptIn() }
            }
        } message: {
            Text("NotchHub will use Notifications only for concise permission recovery messages.")
        }
        .confirmationDialog(
            "Allow Xiaozhi to use the microphone?",
            isPresented: Binding(
                get: { model.isShowingMicrophoneExplanation },
                set: { if !$0 { model.dismissMicrophoneExplanation() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Allow Microphone") {
                Task { await model.confirmXiaozhiMicrophoneConsent() }
            }
        } message: {
            Text(
                "Microphone audio is sent only during an active Xiaozhi conversation. Xiaozhi never starts capture at launch."
            )
        }
    }

    private var statusText: String {
        switch model.notificationsStatus {
        case .notDetermined: "Not enabled"
        case .authorized: "Enabled"
        case .denied: "Not allowed"
        case .restricted: "Restricted"
        case .unavailable: "Unavailable"
        }
    }

    @ViewBuilder private var permissionAction: some View {
        switch model.notificationsStatus {
        case .denied:
            Button("Open System Settings") { Task { _ = await model.openSystemSettings() } }
        case .notDetermined:
            Button("Enable recovery notifications") { model.beginNotificationsRecoveryOptIn() }
        case .authorized, .restricted, .unavailable:
            Text(model.notificationsGuidance.nextAction)
                .font(.caption)
                .foregroundStyle(NotchUITokens.contentSecondary)
        }
    }

    private var microphoneStatusText: String {
        switch model.microphoneStatus {
        case .notDetermined: "Not enabled"
        case .authorized: "Enabled"
        case .denied: "Not allowed"
        case .restricted: "Restricted"
        case .unavailable: "Unavailable"
        }
    }

    @ViewBuilder private var microphoneAction: some View {
        switch model.microphoneStatus {
        case .denied:
            Button("Open System Settings") { Task { _ = await model.openMicrophoneSystemSettings() } }
        case .notDetermined:
            Button("Allow Xiaozhi microphone") { model.beginXiaozhiMicrophoneConsent() }
        case .authorized, .restricted, .unavailable:
            Text(model.microphoneGuidance.nextAction)
                .font(.caption)
                .foregroundStyle(NotchUITokens.contentSecondary)
        }
    }
}

private struct PermissionDetailRow: View {
    let title: String
    let detail: String

    var body: some View {
        LabeledContent(title) {
            Text(detail)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(NotchUITokens.contentSecondary)
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
    }
}

private struct PermissionStatusBadge: View {
    let status: PermissionStatus
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, NotchUITokens.controlSpacing)
            .padding(.vertical, NotchUITokens.microSpacing)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .accessibilityLabel("Notifications: \(text)")
    }

    private var foreground: Color { status == .authorized ? .green : .orange }
    private var background: Color { foreground.opacity(0.15) }
}

extension PermissionKind {
    fileprivate var title: String {
        switch self {
        case .accessibility: "Accessibility"
        case .notifications: "Notifications"
        case .microphone: "Microphone"
        case .calendar: "Calendar"
        case .reminders: "Reminders"
        case .camera: "Camera"
        case .screenRecording: "Screen Recording"
        case .automation: "Automation"
        }
    }
}

private struct SettingsExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: data)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: NotchUITokens.rowSpacing) {
            Text(title).font(NotchUITokens.sectionTitle)
            VStack(alignment: .leading, spacing: NotchUITokens.rowSpacing, content: { content })
                .padding(NotchUITokens.contentPadding)
                .background(
                    .quaternary,
                    in: RoundedRectangle(cornerRadius: NotchUITokens.cardCornerRadius)
                )
        }
    }
}

public struct NHStatusPill: View {
    public let text: String

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, NotchUITokens.controlSpacing)
            .padding(.vertical, NotchUITokens.microSpacing)
            .background(NotchUITokens.statusWarning.opacity(0.15), in: Capsule())
            .accessibilityLabel(text)
    }
}

public struct NHActionButton: View {
    public let title: String
    public let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View { Button(title, action: action) }
}

public struct NHContentState: View {
    public let title: String
    public let symbolName: String
    public let description: String

    public init(title: String, symbolName: String, description: String) {
        self.title = title
        self.symbolName = symbolName
        self.description = description
    }

    public var body: some View {
        ContentUnavailableView(title, systemImage: symbolName, description: Text(description))
            .accessibilityLabel(title)
    }
}

private struct SettingsStatusRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title, value: value)
            .accessibilityElement(children: .combine)
    }
}

private struct SettingsFeedback: View {
    let recovery: SettingsRecoveryOutcome
    let save: SettingsMutationOutcome?

    var body: some View {
        if recovery != .loaded || save != nil {
            Text(message)
                .font(.caption)
                .foregroundStyle(recovery == .loaded && save == .saved ? Color.secondary : Color.orange)
                .accessibilityLabel("Settings status: \(message)")
        }
    }

    private var message: String {
        switch recovery {
        case .recoveredToSafeDefaults: "Settings were corrupt and recovered to safe defaults."
        case .readOnlyFutureSchema: "Settings were created by a newer NotchHub version and are read-only."
        case .persistenceFailed: "Settings could not be saved; the last known good settings remain active."
        case .loaded:
            switch save {
            case .saved: "Settings saved."
            case .rejected: "That settings change was rejected."
            case .readOnly: "Settings are read-only until you update or reset them."
            case .persistenceFailed: "Settings could not be saved; the last known good settings remain active."
            case nil: ""
            }
        }
    }
}

private struct SettingsUnavailableState: View {
    let owner: SettingsOwningPhase

    var body: some View {
        NHContentState(
            title: "Available in \(owner.displayName)",
            symbolName: "clock.badge",
            description: "This route is visible for orientation, but it has no active controls until its "
                + "owning phase is implemented."
        )
    }
}
