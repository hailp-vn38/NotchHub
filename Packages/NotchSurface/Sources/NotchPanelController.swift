import AppKit
import SwiftUI

/// The sole owner of the native Notch panel and its AppKit operations.
@MainActor
public final class NotchPanelController: SurfacePanelPresenting, SurfaceInputMonitoring, DetailNavigationInput,
    SurfaceGeometryRevalidating, SurfaceContextObserving, SurfaceDebugOverlayToggling, SurfaceExpansionAdmitting
{
    private var panel: NSPanel?
    private let presentationModel = NotchSurfacePresentationModel()
    private var hostingView: NSHostingView<NotchSurfaceRootView>?
    private var closeHostSettleTask: Task<Void, Never>?
    private var projectionTask: Task<Void, Never>?
    private var projectionGeneration = 0
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
    private var topologyRevision: UInt64 = 0

    public init() {
        let observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.topologyRevision &+= 1
                if let handler = self?.displayChangeHandler { handler() } else { _ = self?.revalidateGeometry() }
            }
        }
        screenParametersObservation = ScreenParametersObservation(observer)
        let activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.contextChangeHandler?(
                    self?.anotherApplicationOwnsFullScreenSpace() == true
                        ? .fullScreenPolicyEngaged : .fullScreenPolicyCleared)
            }
        }
        activeSpaceObservation = ScreenParametersObservation(
            activeSpaceObserver, center: NSWorkspace.shared.notificationCenter)
    }

    deinit {
        closeHostSettleTask?.cancel()
        projectionTask?.cancel()
        screenParametersObservation?.cancel()
        activeSpaceObservation?.cancel()
    }

    public func apply(_ effect: SurfacePanelEffect) -> Bool {
        switch effect {
        case .showCollapsed: return showCollapsed()
        case .showCompact: return showCompact()
        case .showExpanded(let focus): return showExpanded(focus: focus)
        case .hide, .suppress, .pauseInteraction:
            cancelCloseHostSettle()
            cancelPendingProjection()
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

    public func setDisplayChangeHandler(_ handler: @escaping @MainActor () -> Void) { displayChangeHandler = handler }
    public func setContextChangeHandler(_ handler: @escaping @MainActor (SurfaceIntent) -> Void) {
        contextChangeHandler = handler
    }

    public func revalidateGeometry() -> Bool {
        guard let panel, let frame = surfaceFrame(for: panel.frame.size) else {
            removeEventMonitors()
            panel?.orderOut(nil)
            return false
        }
        panel.setFrame(frame, display: true)
        return true
    }

    public func expandedAvailability() -> SurfaceExpandedAvailability {
        NotchSurfaceGeometry.expandedAvailability(
            in: ScreenTopology(screens: NSScreen.screens.map(screenTopology)), topologyRevision: topologyRevision)
    }

    public func setDebugSnapshot(_ snapshot: SurfaceSnapshot) {
        debugSnapshot = snapshot
        presentationModel.apply(snapshot, collapsedSize: collapsedSize())
        refreshDebugOverlay()
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
        removeEventMonitors()
        cancelCloseHostSettle()
        cancelPendingProjection()
        guard let collapsedSize = collapsedSize(), let frame = surfaceFrame(for: collapsedSize) else { return false }
        let panel = panel ?? makePanel()
        ensurePresentation(on: panel)
        presentationModel.projectCollapsed(collapsedSize: collapsedSize)
        if panel.frame.size == SurfaceExpansionContract.hostSize {
            scheduleCollapsedHostSettle(for: panel, collapsedSize: collapsedSize)
        } else {
            panel.setFrame(frame, display: true)
        }
        panel.orderFrontRegardless()
        panel.resignKey()
        priorKeyWindow?.makeKeyAndOrderFront(nil)
        priorKeyWindow = nil
        self.panel = panel
        return true
    }

    private func showCompact() -> Bool {
        removeEventMonitors()
        cancelCloseHostSettle()
        cancelPendingProjection()
        guard let frame = surfaceFrame(for: NotchSurfaceMetrics.compactSize) else { return false }
        let panel = panel ?? makePanel()
        ensurePresentation(on: panel)
        panel.setFrame(frame, display: true)
        presentationModel.projectCompact()
        panel.orderFrontRegardless()
        panel.resignKey()
        self.panel = panel
        return true
    }

    private func showExpanded(focus: Bool) -> Bool {
        cancelCloseHostSettle()
        cancelPendingProjection()
        guard let frame = surfaceFrame(for: SurfaceExpansionContract.hostSize) else { return false }
        let panel = panel ?? makePanel()
        ensurePresentation(on: panel)
        panel.setFrame(frame, display: true)
        projectExpandedOnNextRunLoop()
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

    private func ensurePresentation(on panel: NSPanel) {
        guard hostingView == nil else { return }
        let rootView = NotchSurfaceRootView(
            model: presentationModel,
            send: { [weak self] intent in self?.interactionHandler?(intent) },
            openDetail: { [weak self] in self?.detailNavigationHandler?(.placeholder) }
        )
        let hostingView = NSHostingView(rootView: rootView)
        panel.contentView = hostingView
        self.hostingView = hostingView
    }

    private func projectExpandedOnNextRunLoop() {
        projectionGeneration &+= 1
        let generation = projectionGeneration
        projectionTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled, self.projectionGeneration == generation else { return }
            self.presentationModel.projectExpanded(collapsedSize: self.collapsedSize())
            self.projectionTask = nil
        }
    }

    private func scheduleCollapsedHostSettle(for panel: NSPanel, collapsedSize: NSSize) {
        projectionGeneration &+= 1
        let generation = projectionGeneration
        closeHostSettleTask = Task { @MainActor [weak self, weak panel] in
            try? await Task.sleep(for: NotchSurfaceMetrics.closeHostSettleDelay)
            guard let self, let panel, !Task.isCancelled, self.projectionGeneration == generation,
                !self.presentationModel.isExpandedGeometry,
                !self.presentationModel.isCompactGeometry,
                let frame = self.surfaceFrame(for: collapsedSize)
            else { return }
            panel.setFrame(frame, display: false)
            self.closeHostSettleTask = nil
        }
    }

    private func cancelCloseHostSettle() {
        projectionGeneration &+= 1
        closeHostSettleTask?.cancel()
        closeHostSettleTask = nil
    }

    private func cancelPendingProjection() {
        projectionGeneration &+= 1
        projectionTask?.cancel()
        projectionTask = nil
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
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
            if event.type == .leftMouseDown, event.window !== panel { self?.interactionHandler?(.clickedOutside) }
            return event
        }
        let global = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.interactionHandler?(.clickedOutside)
        }
        eventMonitors = [local, global].compactMap { $0 }
    }

    private func removeEventMonitors() {
        for monitor in eventMonitors { NSEvent.removeMonitor(monitor) }
        eventMonitors.removeAll()
    }

    private func refreshDebugOverlay() {
        guard debugOverlayEnabled, let panel else {
            presentationModel.debugLabel = nil
            return
        }
        presentationModel.debugLabel =
            "F2 DEBUG  state=\(debugSnapshot.state.rawValue)  frame=\(Int(panel.frame.width))x\(Int(panel.frame.height))"
    }

    private func surfaceFrame(for size: NSSize) -> NSRect? {
        let screens = NSScreen.screens
        let topology = ScreenTopology(screens: screens.map(screenTopology))
        guard let geometry = NotchSurfaceGeometry.frame(for: size, in: topology),
            screens.contains(where: { screenIdentifier(for: $0) == geometry.screenIdentifier })
        else { return nil }
        return geometry.frame
    }

    private func collapsedSize() -> NSSize? {
        NotchSurfaceGeometry.collapsedSize(in: ScreenTopology(screens: NSScreen.screens.map(screenTopology)))
    }

    private func anotherApplicationOwnsFullScreenSpace() -> Bool {
        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        let displayBounds = NSScreen.screens.compactMap { displayID(for: $0).map(CGDisplayBounds) }
        guard !displayBounds.isEmpty,
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[CFString: Any]]
        else { return false }
        return windows.contains { window in
            guard let ownerPID = window[kCGWindowOwnerPID] as? pid_t, ownerPID != ownProcessID,
                (window[kCGWindowLayer] as? Int) == 0
            else { return false }
            let bounds = window[kCGWindowBounds] as! CFDictionary
            guard let frame = CGRect(dictionaryRepresentation: bounds) else { return false }
            return displayBounds.contains { frame.contains($0) }
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
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map {
            CGDirectDisplayID($0.uint32Value)
        }
    }

    private func physicalNotchFrame(on screen: NSScreen) -> NSRect? {
        guard #available(macOS 12.0, *), let left = screen.auxiliaryTopLeftArea,
            let right = screen.auxiliaryTopRightArea
        else { return nil }
        let notch = NSRect(
            x: left.maxX, y: max(left.minY, right.minY), width: right.minX - left.maxX,
            height: min(left.height, right.height))
        return screen.frame.contains(notch) && !notch.isEmpty ? notch : nil
    }
}

private final class ScreenParametersObservation: @unchecked Sendable {
    private let observer: NSObjectProtocol
    private let center: NotificationCenter

    init(_ observer: NSObjectProtocol, center: NotificationCenter = .default) {
        self.observer = observer
        self.center = center
    }

    func cancel() { center.removeObserver(observer) }
}
