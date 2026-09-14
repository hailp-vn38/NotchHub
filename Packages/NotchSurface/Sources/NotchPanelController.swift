import AppKit
import SwiftUI

/// The sole owner of the native Notch panel and its AppKit operations.
@MainActor
public final class NotchPanelController: SurfacePanelPresenting {
    private var panel: NSPanel?

    public init() {}

    public func apply(_ effect: SurfacePanelEffect) -> Bool {
        switch effect {
        case .showCollapsed:
            return showCollapsed()
        case .hide:
            panel?.orderOut(nil)
            return true
        }
    }

    private func showCollapsed() -> Bool {
        guard let screen = builtInScreen() else { return false }

        let panel = panel ?? makePanel()
        panel.setFrame(collapsedFrame(on: screen), display: true)
        panel.orderFrontRegardless()
        self.panel = panel
        return true
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.contentView = NSHostingView(rootView: CollapsedNotchSurfaceView())
        return panel
    }

    private func builtInScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            let displayID =
                screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? NSNumber
            return displayID.map { CGDisplayIsBuiltin($0.uint32Value) != 0 } ?? false
        }
    }

    private func collapsedFrame(on screen: NSScreen) -> NSRect {
        let size = NSSize(width: 120, height: 30)
        let frame = screen.frame
        return NSRect(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}

private struct CollapsedNotchSurfaceView: View {
    var body: some View {
        Capsule()
            .fill(.black)
            .overlay {
                Text("NotchHub")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityLabel("NotchHub collapsed surface")
            }
    }
}
