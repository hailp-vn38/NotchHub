import AppKit
import NotchCore
import NotchSurface
import ServiceManagement
import SwiftUI

@main
struct NotchHubApp: App {
    @NSApplicationDelegateAdaptor(AppShellDelegate.self) private var appShell
    @Environment(\.openWindow) private var openWindow
    @State private var statusMessage = "App shell ready."

    var body: some Scene {
        MenuBarExtra("NotchHub", systemImage: "menubar.rectangle") {
            Text(statusMessage)
                .disabled(true)

            Divider()

            Button("Toggle Notch Surface") {
                perform(.toggleNotchSurface)
            }
            Button("Toggle F2 Surface Debug Overlay") {
                perform(.toggleSurfaceDebugOverlay)
            }
            Button("Show Demo State") {
                perform(.showDemoState)
            }

            Divider()

            Button("Open Settings") {
                perform(.openSettings)
            }
            Button("Open Diagnostics") {
                perform(.openDiagnostics)
            }
            Button("Restart App Shell") {
                perform(.restartAppShell)
            }

            Divider()

            Button("Quit NotchHub") {
                perform(.quit)
            }
        }
        .menuBarExtraStyle(.menu)

        WindowGroup("Settings", id: AppShellPlaceholderScene.settings.windowID) {
            PlaceholderScene(scene: .settings)
        }

        WindowGroup("Diagnostics", id: AppShellPlaceholderScene.diagnostics.windowID) {
            PlaceholderScene(scene: .diagnostics)
        }
    }

    private func perform(_ intent: AppShellMenuIntent) {
        appShell.setSceneOpener(openWindow)
        statusMessage = appShell.perform(intent).message
    }
}

@MainActor
final class AppShellDelegate: NSObject, NSApplicationDelegate {
    private lazy var lifecycleObserver = MacOSAppShellLifecycleObserver()
    private lazy var detailWindow = DetailWindowCoordinator()
    private lazy var notchSurface = SurfaceCoordinator(
        panel: NotchPanelController(),
        detailNavigator: detailWindow
    )
    private lazy var coordinator = AppCoordinator(
        scenePresenter: self,
        lifecycleObserver: lifecycleObserver,
        launchAtLoginController: SMAppServiceLaunchAtLoginController(),
        surfaceController: notchSurface
    )
    private var openScene: ((AppShellPlaceholderScene) -> Void)?

    func applicationDidFinishLaunching(_: Notification) {
        _ = coordinator.start()
    }

    func applicationWillTerminate(_: Notification) {
        coordinator.shutdown()
    }

    func perform(_ intent: AppShellMenuIntent) -> AppShellMenuOutcome {
        let outcome = coordinator.perform(intent)
        if outcome == .quitRequested {
            NSApplication.shared.terminate(nil)
        }
        return outcome
    }

    func setSceneOpener(_ openWindow: OpenWindowAction) {
        openScene = { scene in
            openWindow(id: scene.windowID)
        }
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
