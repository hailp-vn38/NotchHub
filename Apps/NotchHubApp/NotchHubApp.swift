import AppKit
import NotchCore
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
    private lazy var coordinator = AppCoordinator(scenePresenter: self)
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
