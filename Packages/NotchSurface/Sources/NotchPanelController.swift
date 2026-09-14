import AppKit
import SwiftUI

/// The sole owner of the native Notch panel and its AppKit operations.
@MainActor
public final class NotchPanelController: SurfacePanelPresenting, SurfaceInputMonitoring, DetailNavigationInput,
    SurfaceGeometryRevalidating
{
    private var panel: NSPanel?
    private var interactionHandler: (@MainActor (SurfaceIntent) -> Void)?
    private var detailNavigationHandler: (@MainActor (DetailNavigationRequest) -> Void)?
    private var eventMonitors: [Any] = []
    private weak var priorKeyWindow: NSWindow?
    private var screenParametersObservation: ScreenParametersObservation?
    private var displayChangeHandler: (@MainActor () -> Void)?

    public init() {
        let observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                if let handler = self?.displayChangeHandler {
                    handler()
                } else {
                    _ = self?.revalidateGeometry()
                }
            }
        }
        screenParametersObservation = ScreenParametersObservation(observer)
    }

    deinit {
        screenParametersObservation?.cancel()
    }

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

    public func setDisplayChangeHandler(_ handler: @escaping @MainActor () -> Void) {
        displayChangeHandler = handler
    }

    public func revalidateGeometry() -> Bool {
        guard let panel else { return false }
        guard let frame = surfaceFrame(for: panel.frame.size) else {
            removeEventMonitors()
            panel.orderOut(nil)
            return false
        }
        panel.setFrame(frame, display: true)
        return true
    }

    private func showCollapsed() -> Bool {
        guard let frame = surfaceFrame(for: NSSize(width: 136, height: 46)) else { return false }

        removeEventMonitors()
        let panel = panel ?? makePanel()
        panel.setFrame(frame, display: true)
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
        guard let frame = surfaceFrame(for: NSSize(width: 220, height: 52)) else { return false }

        removeEventMonitors()
        let panel = panel ?? makePanel()
        panel.setFrame(frame, display: true)
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
        guard let frame = surfaceFrame(for: NSSize(width: 320, height: 160)) else { return false }

        let panel = panel ?? makePanel()
        panel.setFrame(frame, display: true)
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

    private func surfaceFrame(for size: NSSize) -> NSRect? {
        let screens = NSScreen.screens
        let topology = ScreenTopology(screens: screens.map(screenTopology))
        guard let geometry = NotchSurfaceGeometry.frame(for: size, in: topology),
            screens.indices.contains(where: { screenIdentifier(for: screens[$0]) == geometry.screenIdentifier })
        else { return nil }
        return geometry.frame
    }

    private func screenTopology(for screen: NSScreen) -> ScreenTopology.Screen {
        let displayID = displayID(for: screen)
        return ScreenTopology.Screen(
            identifier: screenIdentifier(for: screen),
            isBuiltIn: displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false,
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            physicalNotchFrame: physicalNotchFrame(on: screen),
            scale: screen.backingScaleFactor
        )
    }

    private func screenIdentifier(for screen: NSScreen) -> String {
        displayID(for: screen).map(String.init) ?? ""
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
            .map { CGDirectDisplayID($0.uint32Value) }
    }

    private func physicalNotchFrame(on screen: NSScreen) -> NSRect? {
        guard #available(macOS 12.0, *) else { return nil }
        guard let left = screen.auxiliaryTopLeftArea,
            let right = screen.auxiliaryTopRightArea
        else { return nil }
        let notch = NSRect(
            x: left.maxX,
            y: max(left.minY, right.minY),
            width: right.minX - left.maxX,
            height: min(left.height, right.height)
        )
        return screen.frame.contains(notch) && !notch.isEmpty ? notch : nil
    }
}

private final class ScreenParametersObservation: @unchecked Sendable {
    private let observer: NSObjectProtocol

    init(_ observer: NSObjectProtocol) {
        self.observer = observer
    }

    func cancel() {
        NotificationCenter.default.removeObserver(observer)
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
