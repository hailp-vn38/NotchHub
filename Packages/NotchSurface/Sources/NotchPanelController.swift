import AppKit
import SwiftUI

/// The sole owner of the native Notch panel and its AppKit operations.
@MainActor
public final class NotchPanelController: SurfacePanelPresenting, SurfaceInputMonitoring, DetailNavigationInput,
    SurfaceGeometryRevalidating, SurfaceContextObserving, SurfaceDebugOverlayToggling
{
    private var panel: NSPanel?
    private var interactionHandler: (@MainActor (SurfaceIntent) -> Void)?
    private var detailNavigationHandler: (@MainActor (DetailNavigationRequest) -> Void)?
    private var eventMonitors: [Any] = []
    private weak var priorKeyWindow: NSWindow?
    private var screenParametersObservation: ScreenParametersObservation?
    private var activeSpaceObservation: ScreenParametersObservation?
    private var displayChangeHandler: (@MainActor () -> Void)?
    private var contextChangeHandler: (@MainActor (SurfaceIntent) -> Void)?
    private var debugSnapshot = SurfaceSnapshot()
    private var debugOverlayEnabled = false

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
        let activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.contextChangeHandler?(
                    self?.anotherApplicationOwnsFullScreenSpace() == true
                        ? .fullScreenPolicyEngaged
                        : .fullScreenPolicyCleared)
            }
        }
        activeSpaceObservation = ScreenParametersObservation(
            activeSpaceObserver,
            center: NSWorkspace.shared.notificationCenter
        )
    }

    deinit {
        screenParametersObservation?.cancel()
        activeSpaceObservation?.cancel()
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
        case .pauseInteraction:
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

    public func setContextChangeHandler(_ handler: @escaping @MainActor (SurfaceIntent) -> Void) {
        contextChangeHandler = handler
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

    public func setDebugSnapshot(_ snapshot: SurfaceSnapshot) {
        debugSnapshot = snapshot
    }

    public func toggleDebugOverlay() -> Bool {
        #if DEBUG
            debugOverlayEnabled.toggle()
            refreshDebugOverlay()
            return true
        #else
            return false
        #endif
    }

    private func showCollapsed() -> Bool {
        guard let frame = surfaceFrame(for: NSSize(width: 136, height: 46)) else { return false }

        removeEventMonitors()
        let panel = panel ?? makePanel()
        panel.setFrame(frame, display: true)
        panel.contentView = NSHostingView(
            rootView: CollapsedNotchSurfaceView { [weak self] intent in
                self?.interactionHandler?(intent)
            }
            .overlay(alignment: .bottomLeading) { debugOverlay(for: panel) })
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
            }
            .overlay(alignment: .bottomLeading) { debugOverlay(for: panel) })
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
            }
            .overlay(alignment: .bottomLeading) { debugOverlay(for: panel) })
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
        // This keeps the utility surface reachable across Spaces while policy suppression owns full-screen visibility.
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

    private func refreshDebugOverlay() {
        guard panel != nil else { return }
        switch debugSnapshot.state {
        case .collapsed: _ = showCollapsed()
        case .compact: _ = showCompact()
        case .expanded: _ = showExpanded(focus: false)
        case .hidden, .suppressed, .recovering: break
        }
    }

    @ViewBuilder
    private func debugOverlay(for panel: NSPanel) -> some View {
        if debugOverlayEnabled {
            SurfaceDebugOverlay(
                snapshot: debugSnapshot,
                frame: panel.frame,
                collectionBehavior: panel.collectionBehavior,
                level: panel.level,
                screenIdentifier: panel.screen.map(screenIdentifier(for:)) ?? "unavailable"
            )
        }
    }

    private func surfaceFrame(for size: NSSize) -> NSRect? {
        let screens = NSScreen.screens
        let topology = ScreenTopology(screens: screens.map(screenTopology))
        guard let geometry = NotchSurfaceGeometry.frame(for: size, in: topology),
            screens.indices.contains(where: { screenIdentifier(for: screens[$0]) == geometry.screenIdentifier })
        else { return nil }
        return geometry.frame
    }

    private func anotherApplicationOwnsFullScreenSpace() -> Bool {
        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        let displayBounds = NSScreen.screens.compactMap { screen in
            displayID(for: screen).map(CGDisplayBounds)
        }
        guard !displayBounds.isEmpty,
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[CFString: Any]]
        else { return false }
        return windows.contains { window in
            guard let ownerPID = window[kCGWindowOwnerPID] as? pid_t,
                ownerPID != ownProcessID,
                (window[kCGWindowLayer] as? Int) == 0
            else { return false }
            let bounds = window[kCGWindowBounds] as! CFDictionary  // CoreGraphics guarantees this window-list field.
            guard let frame = CGRect(dictionaryRepresentation: bounds) else { return false }
            return displayBounds.contains { screen in
                frame.contains(screen)
            }
        }
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

private struct SurfaceDebugOverlay: View {
    let snapshot: SurfaceSnapshot
    let frame: NSRect
    let collectionBehavior: NSWindow.CollectionBehavior
    let level: NSWindow.Level
    let screenIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: "F2 DEBUG  state=\(snapshot.state.rawValue)  paused=\(snapshot.isInteractionPaused)")
            Text(
                verbatim: "frame=\(Int(frame.origin.x)),\(Int(frame.origin.y)) \(Int(frame.width))×\(Int(frame.height))"
            )
            Text(verbatim: "screen=\(screenIdentifier) level=\(level.rawValue)")
            Text(
                verbatim:
                    "flags=\(collectionBehavior.rawValue) suppress=\(snapshot.suppressionReason.map { String(describing: $0) } ?? "none")"
            )
            Text(
                verbatim:
                    "recovery=\(snapshot.recoveryAttemptCount) \(snapshot.recoveryOutcome.map { String(describing: $0) } ?? "none")"
            )
        }
        .font(.system(size: 8, design: .monospaced))
        .foregroundStyle(.green)
        .padding(4)
        .background(.black.opacity(0.85))
        .accessibilityLabel("F2 surface debug overlay")
    }
}

private final class ScreenParametersObservation: @unchecked Sendable {
    private let observer: NSObjectProtocol
    private let center: NotificationCenter

    init(_ observer: NSObjectProtocol, center: NotificationCenter = .default) {
        self.observer = observer
        self.center = center
    }

    func cancel() {
        center.removeObserver(observer)
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
