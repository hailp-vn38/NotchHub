import AppKit
import NotchCore
import SwiftUI

@main
struct NotchHubApp: App {
    @NSApplicationDelegateAdaptor(AppShellDelegate.self) private var appShell
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
            Button("Restart App Shell") {
                perform(.restartAppShell)
            }

            Divider()

            Button("Quit NotchHub") {
                perform(.quit)
            }
        }
        .menuBarExtraStyle(.menu)
    }

    private func perform(_ intent: AppShellMenuIntent) {
        statusMessage = appShell.perform(intent).message
    }
}

@MainActor
final class AppShellDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = AppCoordinator()

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
}
