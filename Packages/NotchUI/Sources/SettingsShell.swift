import Observation
import SwiftUI

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

    public init(selectedRoute: SettingsRoute = .general) {
        self.selectedRoute = selectedRoute
    }

    public func select(_ route: SettingsRoute) {
        selectedRoute = route
    }

    public func routeState(for route: SettingsRoute) -> SettingsRouteState {
        switch route {
        case .general, .appearance, .notchBehavior, .about:
            .init(route: route, owningPhase: .f3, isInteractive: true)
        case .shortcuts, .actions:
            .init(route: route, owningPhase: .f6, isInteractive: false)
        case .permissions:
            .init(route: route, owningPhase: .f5, isInteractive: false)
        case .modules:
            .init(route: route, owningPhase: .f7, isInteractive: false)
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
        systemPreference || sessionMotionPreference == .reduced
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
                .id(model.selectedRoute)
                .transition(.opacity)
                .animation(
                    model.isReducedMotion(systemPreference: systemReducedMotion)
                        ? .easeOut(duration: 0.12) : .spring(response: 0.35, dampingFraction: 0.9),
                    value: model.selectedRoute
                )
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 560)
    }
}

private struct SettingsPageView: View {
    @Bindable var model: SettingsShellModel
    let systemReducedMotion: Bool

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
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(NotchUITokens.contentPadding)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func interactiveContent(for route: SettingsRoute) -> some View {
        switch route {
        case .appearance:
            SettingsSection(title: "Motion") {
                Picker(
                    "Motion preference",
                    selection: Binding(
                        get: { model.sessionMotionPreference },
                        set: { _ = model.setSessionMotionPreference($0) }
                    )
                ) {
                    ForEach(SettingsMotionPreference.allCases, id: \.self) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
                Text("This preview applies only while NotchHub is running and is not saved.")
                    .font(.caption)
                    .foregroundStyle(NotchUITokens.contentSecondary)
            }
        case .notchBehavior:
            SettingsSection(title: "Current surface behavior") {
                SettingsStatusRow(title: "Hover", value: "300 ms delay")
                SettingsStatusRow(title: "Auto-collapse", value: "3 seconds")
                Text("Persisted Notch behavior preferences arrive in F4.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .general:
            SettingsSection(title: "Foundation") {
                Text(
                    "Settings navigation and reusable presentation are ready. Configuration persistence, "
                        + "import, export, and reset arrive in F4."
                )
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
        case .shortcuts, .permissions, .actions, .modules, .diagnostics:
            EmptyView()
        }
    }

    private func subtitle(for route: SettingsRoute) -> String {
        switch route {
        case .general: "Application information and the current foundation boundary."
        case .appearance: "Preview visual behavior without saving a preference."
        case .notchBehavior: "Explain the current safe surface defaults."
        case .shortcuts: "Keyboard shortcut registration arrives in F6."
        case .permissions: "Permission Center arrives in F5."
        case .actions: "Registered actions arrive in F6."
        case .modules: "Module runtime arrives in F7."
        case .diagnostics: "Operational diagnostics arrive in F9."
        case .about: "Application information safe to show in the foundation."
        }
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
