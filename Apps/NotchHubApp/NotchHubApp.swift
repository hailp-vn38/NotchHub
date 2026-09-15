import AppKit
import NotchActions
import NotchCore
import NotchDomain
import NotchSurface
import NotchUI
import ServiceManagement
import SwiftUI
import XiaozhiModule

#if DEBUG
    import NotchDemoModule
#endif

@main
struct NotchHubApp: App {
    @NSApplicationDelegateAdaptor(AppShellDelegate.self) private var appShell
    @Environment(\.openWindow) private var openWindow
    var body: some Scene {
        MenuBarExtra("NotchHub", systemImage: "menubar.rectangle") {
            Button("Settings") {
                perform(.openSettings)
            }
            Button("Restart App Shell") {
                perform(.restartAppShell)
            }
            Button("Quit") {
                perform(.quit)
            }
        }
        .menuBarExtraStyle(.menu)

        Window("Settings", id: AppShellPlaceholderScene.settings.windowID) {
            SettingsShellView(model: appShell.settingsShell)
        }

        WindowGroup("Diagnostics", id: AppShellPlaceholderScene.diagnostics.windowID) {
            PlaceholderScene(scene: .diagnostics)
        }
    }

    private func perform(_ intent: AppShellMenuIntent) {
        appShell.setSceneOpener(openWindow)
        _ = appShell.perform(intent)
    }
}

@MainActor
final class AppShellDelegate: NSObject, NSApplicationDelegate {
    private let settingsRuntime = SurfaceSettingsRuntime()
    private let settingsStore: SettingsStore
    private let permissionCoordinator: PermissionCoordinator
    private let shortcutBindings: ShortcutBindingStore
    private let moduleRuntime: ModuleRuntime
    let permissionCenter: PermissionCenterModel
    let settingsShell: SettingsShellModel
    private lazy var lifecycleObserver = MacOSAppShellLifecycleObserver()
    private lazy var notchPanel = NotchPanelController(sessionMotionPreference: { [weak settingsShell] in
        settingsShell?.settings.appearance.reducedMotion == .reduceMotion
    })
    private lazy var notchSurface = SurfaceCoordinator(panel: notchPanel)
    private lazy var coordinator = AppCoordinator(
        scenePresenter: self,
        lifecycleObserver: lifecycleObserver,
        launchAtLoginController: SMAppServiceLaunchAtLoginController(),
        surfaceController: notchSurface,
        permissionStatusRefresher: PermissionCenterRefreshBridge(permissionCenter: permissionCenter)
    )
    private var openScene: ((AppShellPlaceholderScene) -> Void)?

    override init() {
        let backend = FileSettingsBackend.applicationSupport()
        settingsStore = SettingsStore(backend: backend, runtime: settingsRuntime)
        moduleRuntime = ModuleRuntime(settingsStore: settingsStore)
        shortcutBindings = ShortcutBindingStore(settingsStore: settingsStore)
        permissionCoordinator = PermissionCoordinator(
            adapter: PermissionAdapterRegistry([
                .notifications: NotificationsPermissionAdapter(),
                .microphone: XiaozhiMicrophonePermissionAdapter(),
            ]),
            requirements: [
                .init(featureID: PermissionFeatureID.recoveryNotifications, kind: .notifications),
                .init(featureID: PermissionFeatureID.xiaozhi, kind: .microphone),
            ]
        )
        permissionCenter = PermissionCenterModel(coordinator: permissionCoordinator)
        settingsShell = SettingsShellModel(
            settingsStore: settingsStore,
            permissionCenter: permissionCenter,
            shortcutPresentation: ShortcutPresentationModel(bindingStore: shortcutBindings),
            moduleRuntime: moduleRuntime
        )
        super.init()
    }

    func applicationDidFinishLaunching(_: Notification) {
        lifecycleObserver.additionalHandler = { [moduleRuntime] event in
            switch event {
            case .willSleep, .locked, .willTerminate:
                Task { await moduleRuntime.send(.endTransientSession, to: ModuleID("xiaozhi")!) }
            case .activated, .deactivated, .didWake, .unlocked:
                break
            }
        }
        settingsRuntime.surface = notchSurface
        notchPanel.setActionHandler { [weak self] id in
            guard let self else { return }
            Task {
                await self.moduleRuntime.actions.invoke(id)
                await self.refreshSurfaceContributions()
            }
        }
        Task { [weak self, moduleRuntime] in
            for await contributions in await moduleRuntime.contributionUpdates() {
                guard let self else { return }
                self.notchSurface.apply(contributions: contributions)
            }
        }
        Task {
            let settings = await settingsStore.load().settings
            let xiaozhi = XiaozhiModule(
                permissionCoordinator: permissionCoordinator,
                ttsMutedProvider: { await self.settingsStore.load().settings.xiaozhi.ttsMuted }
            )
            await moduleRuntime.register(
                xiaozhi,
                enabled: settings.modules[xiaozhi.id.rawValue]?.isEnabled ?? false
            )
            if settings.modules[xiaozhi.id.rawValue]?.isEnabled == true {
                await moduleRuntime.start(xiaozhi.id)
            }
            #if DEBUG
                let demo = NotchDemoModule()
                await moduleRuntime.register(demo, enabled: settings.modules[demo.id.rawValue]?.isEnabled ?? true)
                await moduleRuntime.start(demo.id)
            #endif
            await refreshSurfaceContributions()
            await settingsShell.loadSettings()
        }
        _ = coordinator.start()
    }

    private func refreshSurfaceContributions() async {
        let contributions = await moduleRuntime.allContributions()
        await MainActor.run { [weak self] in self?.notchSurface.apply(contributions: contributions) }
    }

    func applicationWillTerminate(_: Notification) {
        coordinator.shutdown()
        Task { await moduleRuntime.shutdown() }
    }

    func perform(_ intent: AppShellMenuIntent) -> AppShellMenuOutcome {
        let outcome = coordinator.perform(intent)
        if outcome == .quitRequested {
            NSApplication.shared.terminate(nil)
        }
        return outcome
    }

    func setSceneOpener(_ openWindow: OpenWindowAction) {
        openScene = { [weak self] scene in
            openWindow(id: scene.windowID)

            guard scene == .settings else { return }
            self?.focusSettingsWindowWhenReady()
        }
    }

    /// `openWindow(id:)` activates a scene, but the native window can be
    /// materialized one run-loop turn later. Re-apply key/front focus once it
    /// exists so repeated menu-bar selections also restore the existing window.
    /// This intentionally does not change the window level, so Settings is not
    /// made permanently always-on-top.
    private func focusSettingsWindowWhenReady(attemptsRemaining: Int = 3) {
        guard
            let window = NSApp.windows.first(where: { window in
                window.title == AppShellPlaceholderScene.settings.title
                    || window.identifier?.rawValue == AppShellPlaceholderScene.settings.windowID
            })
        else {
            guard attemptsRemaining > 0 else { return }
            DispatchQueue.main.async { [weak self] in
                self?.focusSettingsWindowWhenReady(attemptsRemaining: attemptsRemaining - 1)
            }
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private final class SurfaceSettingsRuntime: SettingsProjectionApplying {
    weak var surface: SurfaceCoordinator?

    func apply(_ projection: SettingsProjection) async {
        surface?.applySettings(projection)
    }
}

@MainActor
private final class PermissionCenterRefreshBridge: PermissionStatusRefreshing {
    private let permissionCenter: PermissionCenterModel

    init(permissionCenter: PermissionCenterModel) {
        self.permissionCenter = permissionCenter
    }

    func refreshPermissionStatus() {
        Task { await permissionCenter.load() }
    }
}

extension AppShellDelegate: AppShellScenePresenter {
    func present(_ scene: AppShellPlaceholderScene) -> AppShellScenePresentationResult {
        guard let openScene else { return .unavailable }
        openScene(scene)
        return .presented
    }
}

@MainActor
private final class MacOSAppShellLifecycleObserver: AppShellLifecycleObserving {
    private var observerRemovals: [() -> Void] = []
    var additionalHandler: ((AppShellLifecycleEvent) -> Void)?

    func start(observing handler: @escaping @MainActor (AppShellLifecycleEvent) -> Void) {
        guard observerRemovals.isEmpty else { return }

        let appNotifications = NotificationCenter.default
        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        func observe(
            _ center: NotificationCenter,
            named name: Notification.Name,
            as event: AppShellLifecycleEvent
        ) -> () -> Void {
            let registration = center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    handler(event)
                    self.additionalHandler?(event)
                }
            }
            return { center.removeObserver(registration) }
        }

        observerRemovals = [
            observe(appNotifications, named: NSApplication.didBecomeActiveNotification, as: .activated),
            observe(appNotifications, named: NSApplication.didResignActiveNotification, as: .deactivated),
            observe(appNotifications, named: NSApplication.willTerminateNotification, as: .willTerminate),
            observe(workspaceNotifications, named: NSWorkspace.willSleepNotification, as: .willSleep),
            observe(workspaceNotifications, named: NSWorkspace.didWakeNotification, as: .didWake),
            observe(workspaceNotifications, named: NSWorkspace.sessionDidResignActiveNotification, as: .locked),
            observe(workspaceNotifications, named: NSWorkspace.sessionDidBecomeActiveNotification, as: .unlocked),
        ]
    }

    func stop() {
        for removeObserver in observerRemovals.reversed() {
            removeObserver()
        }
        observerRemovals.removeAll()
    }
}

@MainActor
private struct SMAppServiceLaunchAtLoginController: LaunchAtLoginControlling {
    func status() -> LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            .notRegistered
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .notFound
        @unknown default:
            .unavailable
        }
    }
}

private struct PlaceholderScene: View {
    let scene: AppShellPlaceholderScene

    var body: some View {
        ContentUnavailableView(
            "\(scene.title) placeholder",
            systemImage: "hammer",
            description: Text(
                "F1 only: this scene has no persistence, operational records, module runtime, IPC listener, or Notch surface."
            )
        )
        .frame(minWidth: 440, minHeight: 260)
        .padding()
    }
}
