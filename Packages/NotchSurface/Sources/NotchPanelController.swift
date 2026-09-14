import AppKit
import SwiftUI

/// The sole owner of the native Notch panel and its AppKit operations.
@MainActor
public final class NotchPanelController: SurfacePanelPresenting, SurfaceInputMonitoring, DetailNavigationInput {
    private var panel: NSPanel?
    private var interactionHandler: (@MainActor (SurfaceIntent) -> Void)?
    private var detailNavigationHandler: (@MainActor (DetailNavigationRequest) -> Void)?
    private var eventMonitors: [Any] = []
    private weak var priorKeyWindow: NSWindow?

    public init() {}

    public func apply(_ effect: SurfacePanelEffect) -> Bool {
        switch effect {
        case .showCollapsed:
            return showCollapsed()
        case .showCompact:
            return showCompact()
        case .showExpanded(let focus):
            return showExpanded(focus: focus)
        case .hide:
            removeEventMonitors()
            panel?.orderOut(nil)
            return true
        case .suppress:
            removeEventMonitors()
            panel?.orderOut(nil)
            return true
        }
    }

    public func setInteractionHandler(_ handler: @escaping @MainActor (SurfaceIntent) -> Void) {
        interactionHandler = handler
    }

    public func setDetailNavigationHandler(_ handler: @escaping @MainActor (DetailNavigationRequest) -> Void) {
        detailNavigationHandler = handler
    }

    private func showCollapsed() -> Bool {
        guard let screen = builtInScreen() else { return false }

        removeEventMonitors()
        let panel = panel ?? makePanel()
        panel.setFrame(collapsedFrame(on: screen), display: true)
        panel.contentView = NSHostingView(
            rootView: CollapsedNotchSurfaceView { [weak self] intent in
                self?.interactionHandler?(intent)
            })
        panel.orderFrontRegardless()
        panel.resignKey()
        priorKeyWindow?.makeKeyAndOrderFront(nil)
        priorKeyWindow = nil
        self.panel = panel
        return true
    }

    private func showCompact() -> Bool {
        guard let screen = builtInScreen() else { return false }

        removeEventMonitors()
        let panel = panel ?? makePanel()
        panel.setFrame(compactFrame(on: screen), display: true)
        panel.contentView = NSHostingView(
            rootView: CompactNotchSurfaceView { [weak self] in
                self?.interactionHandler?(.clicked)
            })
        panel.orderFrontRegardless()
        panel.resignKey()
        self.panel = panel
        return true
    }

    private func showExpanded(focus: Bool) -> Bool {
        guard let screen = builtInScreen() else { return false }

        let panel = panel ?? makePanel()
        panel.setFrame(expandedFrame(on: screen), display: true)
        panel.contentView = NSHostingView(
            rootView: ExpandedNotchSurfaceView { [weak self] intent in
                self?.interactionHandler?(intent)
            } openDetail: { [weak self] in
                self?.detailNavigationHandler?(.placeholder)
            })
        installExpandedEventMonitors()
        if focus {
            priorKeyWindow = NSApp.keyWindow
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
        self.panel = panel
        return true
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: .borderless,
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
        return panel
    }

    private func installExpandedEventMonitors() {
        removeEventMonitors()
        let local = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) {
            [weak self, weak panel] event in
            if event.type == .keyDown, event.keyCode == 53 {
                self?.interactionHandler?(.escapePressed)
                return nil
            }
            if event.type == .leftMouseDown, event.window !== panel {
                self?.interactionHandler?(.clickedOutside)
            }
            return event
        }
        let global = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.interactionHandler?(.clickedOutside)
        }
        eventMonitors = [local, global].compactMap { $0 }
    }

    private func removeEventMonitors() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
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
        let size = NSSize(width: 136, height: 46)
        let frame = screen.frame
        return NSRect(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func expandedFrame(on screen: NSScreen) -> NSRect {
        let size = NSSize(width: 320, height: 160)
        let frame = screen.frame
        return NSRect(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func compactFrame(on screen: NSScreen) -> NSRect {
        let size = NSSize(width: 220, height: 52)
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
    let send: (SurfaceIntent) -> Void

    var body: some View {
        Capsule()
            .fill(.black)
            .frame(width: 120, height: 30)
            .overlay {
                Text("NotchHub")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityLabel("NotchHub collapsed surface")
            }
            .frame(width: 136, height: 46)
            .contentShape(Rectangle())
            .onHover { send($0 ? .hoverEntered : .hoverExited) }
            .onTapGesture { send(.clicked) }
    }
}

private struct ExpandedNotchSurfaceView: View {
    let send: (SurfaceIntent) -> Void
    let openDetail: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("NotchHub")
                .font(.headline)
            Text("Surface ready")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("View detail", action: openDetail)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .onHover { send($0 ? .expandedHoverEntered : .expandedHoverExited) }
        .onTapGesture { send(.interaction) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("NotchHub expanded surface")
    }
}

private struct CompactNotchSurfaceView: View {
    let expand: () -> Void

    var body: some View {
        Text("Surface ready")
            .font(.subheadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .contentShape(Rectangle())
            .onTapGesture(perform: expand)
            .accessibilityLabel("NotchHub compact surface")
    }
}
