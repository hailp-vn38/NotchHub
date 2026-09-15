import AppKit
import NotchCore
import SwiftUI

/// The sole owner of the native Notch panel and its AppKit operations.
@MainActor
public final class NotchPanelController: SurfacePanelPresenting, SurfaceInputMonitoring,
    SurfaceGeometryRevalidating, SurfaceContextObserving, SurfaceDebugOverlayToggling,
    SurfaceExpansionAdmitting, SurfaceFocusRestoring, SurfaceAppearanceApplying
{
    private var panel: NSPanel?
    private let presentationModel: NotchSurfacePresentationModel
    private var hostingView: NSHostingView<NotchSurfaceRootView>?
    private var interactionHandler: (@MainActor (SurfaceIntent) -> Void)?
    private var eventMonitors: [Any] = []
    private weak var priorKeyWindow: NSWindow?
    private var screenParametersObservation: ScreenParametersObservation?
    private var activeSpaceObservation: ScreenParametersObservation?
    private var displayChangeHandler: (@MainActor () -> Void)?
    private var contextChangeHandler: (@MainActor (SurfaceIntent) -> Void)?
    private var debugSnapshot = SurfaceSnapshot()
    private var debugOverlayEnabled = false
    private var topologyRevision: UInt64 = 0
    private var nativeMouseCaptureDepth = 0

    public init(sessionMotionPreference: @escaping @MainActor () -> Bool = { false }) {
        presentationModel = NotchSurfacePresentationModel(
            sessionMotionPreference: sessionMotionPreference
        )
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
        screenParametersObservation?.cancel()
        activeSpaceObservation?.cancel()
    }

    public func apply(_ effect: SurfacePanelEffect) -> Bool {
        switch effect {
        case .showCollapsed: return showCollapsed()
        case .showCompact: return showCompact()
        case .showExpanded(let focus): return showExpanded(focus: focus)
        case .hide, .suppress, .pauseInteraction:
            removeEventMonitors()
            nativeMouseCaptureDepth = 0
            panel?.ignoresMouseEvents = true
            panel?.orderOut(nil)
            restoreFocusAfterSurfaceInteraction()
            return true
        }
    }

    public func setInteractionHandler(_ handler: @escaping @MainActor (SurfaceIntent) -> Void) {
        interactionHandler = handler
    }

    public func setDisplayChangeHandler(_ handler: @escaping @MainActor () -> Void) { displayChangeHandler = handler }
    public func setContextChangeHandler(_ handler: @escaping @MainActor (SurfaceIntent) -> Void) {
        contextChangeHandler = handler
    }

    public func revalidateGeometry() -> Bool {
        guard let frame = surfaceFrame() else {
            removeEventMonitors()
            panel?.orderOut(nil)
            return false
        }
        let panel = panel ?? makePanel()
        self.panel = panel
        ensurePresentation(on: panel)
        panel.setFrame(frame, display: true)
        refreshNativeHitTesting()
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

    public func apply(theme: SettingsTheme) {
        presentationModel.apply(theme: theme)
    }

    /// Keeps the native panel interactive while a control owns a mouse gesture.
    public func beginNativeMouseCapture() {
        nativeMouseCaptureDepth += 1
        refreshNativeHitTesting()
    }

    /// Ends one native mouse gesture and restores shape-aware click-through.
    public func endNativeMouseCapture() {
        guard nativeMouseCaptureDepth > 0 else { return }
        nativeMouseCaptureDepth -= 1
        refreshNativeHitTesting()
    }

    public func restoreFocusAfterSurfaceInteraction() {
        guard let priorKeyWindow else {
            panel?.resignKey()
            return
        }
        priorKeyWindow.makeKeyAndOrderFront(nil)
        self.priorKeyWindow = nil
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
        guard let collapsedSize = collapsedSize(), let frame = surfaceFrame() else { return false }
        let panel = panel ?? makePanel()
        self.panel = panel
        ensurePresentation(on: panel)
        presentationModel.projectCollapsed(collapsedSize: collapsedSize)
        panel.setFrame(frame, display: true)
        installPointerMonitors()
        refreshNativeHitTesting()
        panel.orderFrontRegardless()
        panel.resignKey()
        priorKeyWindow?.makeKeyAndOrderFront(nil)
        priorKeyWindow = nil
        return true
    }

    private func showCompact() -> Bool {
        removeEventMonitors()
        guard let frame = surfaceFrame() else { return false }
        let panel = panel ?? makePanel()
        self.panel = panel
        ensurePresentation(on: panel)
        panel.setFrame(frame, display: true)
        presentationModel.projectCompact()
        installPointerMonitors()
        refreshNativeHitTesting()
        panel.orderFrontRegardless()
        panel.resignKey()
        return true
    }

    private func showExpanded(focus: Bool) -> Bool {
        guard let frame = surfaceFrame() else { return false }
        let panel = panel ?? makePanel()
        self.panel = panel
        ensurePresentation(on: panel)
        panel.setFrame(frame, display: true)
        presentationModel.projectExpanded(collapsedSize: collapsedSize())
        installExpandedEventMonitors()
        refreshNativeHitTesting()
        if focus {
            priorKeyWindow = NSApp.keyWindow
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
        return true
    }

    private func ensurePresentation(on panel: NSPanel) {
        guard hostingView == nil else { return }
        let rootView = NotchSurfaceRootView(
            model: presentationModel,
            send: { [weak self] intent in self?.interactionHandler?(intent) }
        )
        let hostingView = NSHostingView(rootView: rootView)
        panel.contentView = hostingView
        self.hostingView = hostingView
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

    private func installPointerMonitors() {
        removeEventMonitors()
        let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.refreshNativeHitTesting(pointerLocation: NSEvent.mouseLocation)
            return event
        }
        let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.refreshNativeHitTesting(pointerLocation: NSEvent.mouseLocation)
        }
        eventMonitors = [local, global].compactMap { $0 }
    }

    private func installExpandedEventMonitors() {
        removeEventMonitors()
        let local = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .mouseMoved]) {
            [weak self] event in
            if event.type == .mouseMoved {
                self?.refreshNativeHitTesting(pointerLocation: NSEvent.mouseLocation)
                return event
            }
            if event.type == .keyDown, event.keyCode == 53 {
                self?.interactionHandler?(.escapePressed)
                return nil
            }
            if event.type == .leftMouseDown,
                let self,
                self.shouldDismissForClick(pointerLocation: NSEvent.mouseLocation)
            {
                self.interactionHandler?(.clickedOutside)
            }
            return event
        }
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] event in
            if event.type == .mouseMoved {
                self?.refreshNativeHitTesting(pointerLocation: NSEvent.mouseLocation)
            } else {
                guard let self, self.shouldDismissForClick(pointerLocation: NSEvent.mouseLocation) else { return }
                self.interactionHandler?(.clickedOutside)
            }
        }
        eventMonitors = [local, global].compactMap { $0 }
    }

    private func refreshNativeHitTesting(pointerLocation: NSPoint = NSEvent.mouseLocation) {
        guard let panel else { return }
        let inside = isPointerInsideSurface(pointerLocation: pointerLocation)
        panel.ignoresMouseEvents = nativeMouseCaptureDepth == 0 && !inside
    }

    private func shouldDismissForClick(pointerLocation: NSPoint) -> Bool {
        guard let panel else { return false }
        let point = surfacePoint(pointerLocation: pointerLocation, panelFrame: panel.frame)
        return NotchSurfaceHitTesting.shouldDismissForClick(
            point: point,
            hostSize: panel.frame.size,
            surfaceSize: presentationModel.visibleSurfaceSize,
            topShoulderRadius: presentationModel.topShoulderRadius,
            bottomCornerRadius: presentationModel.bottomCornerRadius)
    }

    private func isPointerInsideSurface(pointerLocation: NSPoint) -> Bool {
        guard let panel else { return false }
        return NotchSurfaceHitTesting.contains(
            point: surfacePoint(pointerLocation: pointerLocation, panelFrame: panel.frame),
            hostSize: panel.frame.size,
            surfaceSize: presentationModel.visibleSurfaceSize,
            topShoulderRadius: presentationModel.topShoulderRadius,
            bottomCornerRadius: presentationModel.bottomCornerRadius)
    }

    private func surfacePoint(pointerLocation: NSPoint, panelFrame: NSRect) -> CGPoint {
        CGPoint(x: pointerLocation.x - panelFrame.minX, y: panelFrame.maxY - pointerLocation.y)
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

    private func surfaceFrame() -> NSRect? {
        let screens = NSScreen.screens
        let topology = ScreenTopology(screens: screens.map(screenTopology))
        guard let geometry = NotchSurfaceGeometry.frame(for: SurfaceExpansionContract.hostSize, in: topology),
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
