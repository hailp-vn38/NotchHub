import Foundation

/// A testable snapshot of the displays relevant to the Notch surface.
public struct ScreenTopology: Equatable, Sendable {
    public struct Screen: Equatable, Sendable {
        public let identifier: String
        public let isBuiltIn: Bool
        public let frame: CGRect
        public let visibleFrame: CGRect
        public let physicalNotchFrame: CGRect?
        public let scale: CGFloat

        public init(
            identifier: String,
            isBuiltIn: Bool,
            frame: CGRect,
            visibleFrame: CGRect,
            physicalNotchFrame: CGRect? = nil,
            scale: CGFloat
        ) {
            self.identifier = identifier
            self.isBuiltIn = isBuiltIn
            self.frame = frame
            self.visibleFrame = visibleFrame
            self.physicalNotchFrame = physicalNotchFrame
            self.scale = scale
        }
    }

    public let screens: [Screen]

    public init(screens: [Screen]) {
        self.screens = screens
    }
}

public struct NotchSurfaceFrame: Equatable, Sendable {
    public let screenIdentifier: String
    public let frame: CGRect

    public init(screenIdentifier: String, frame: CGRect) {
        self.screenIdentifier = screenIdentifier
        self.frame = frame
    }
}

/// Selects only the built-in display and anchors the native host at its real top edge.
public enum NotchSurfaceGeometry {
    public static let fallbackCollapsedSize = CGSize(width: 185, height: 32)
    public static let physicalNotchWidthTolerance: CGFloat = 4

    /// Uses the physical camera housing when it is valid, with a safe top-center fallback otherwise.
    public static func collapsedSize(in topology: ScreenTopology) -> CGSize? {
        guard let screen = topology.screens.first(where: { $0.isBuiltIn }), isValid(screen) else {
            return nil
        }
        guard let notch = screen.physicalNotchFrame,
            screen.frame.contains(notch),
            !notch.isEmpty
        else {
            return fallbackCollapsedSize
        }
        return CGSize(width: notch.width + physicalNotchWidthTolerance, height: notch.height)
    }

    public static func expandedAvailability(
        in topology: ScreenTopology,
        topologyRevision: UInt64
    ) -> SurfaceExpandedAvailability {
        guard let screen = topology.screens.first(where: { $0.isBuiltIn }), isValid(screen) else {
            return .invalidTopology(topologyRevision: topologyRevision)
        }
        return fixedFrame(for: SurfaceExpansionContract.hostSize, on: screen) == nil
            ? .unsupportedCapacity(topologyRevision: topologyRevision)
            : .available(topologyRevision: topologyRevision)
    }

    public static func frame(
        for preferredSize: CGSize,
        in topology: ScreenTopology
    ) -> NotchSurfaceFrame? {
        guard preferredSize.width > 0, preferredSize.height > 0,
            let screen = topology.screens.first(where: { $0.isBuiltIn }),
            isValid(screen)
        else { return nil }

        let validNotch = validPhysicalNotch(on: screen)
        let placementFrame = screen.frame
        guard placementFrame.width >= preferredSize.width, placementFrame.height >= preferredSize.height else {
            return nil
        }

        let anchorX = validNotch?.midX ?? placementFrame.midX
        let originX = min(
            max(anchorX - preferredSize.width / 2, placementFrame.minX),
            placementFrame.maxX - preferredSize.width)
        let frame = CGRect(
            x: originX, y: placementFrame.maxY - preferredSize.height,
            width: preferredSize.width, height: preferredSize.height)
        guard placementFrame.contains(frame) else { return nil }

        return NotchSurfaceFrame(screenIdentifier: screen.identifier, frame: frame)
    }

    private static func fixedFrame(
        for size: CGSize,
        on screen: ScreenTopology.Screen
    ) -> NotchSurfaceFrame? {
        guard size.width > 0, size.height > 0 else { return nil }
        let validNotch = validPhysicalNotch(on: screen)
        let placementFrame = screen.frame
        guard placementFrame.width >= size.width, placementFrame.height >= size.height else { return nil }
        let anchorX = validNotch?.midX ?? placementFrame.midX
        let originX = anchorX - size.width / 2
        let frame = CGRect(
            x: originX, y: placementFrame.maxY - size.height,
            width: size.width, height: size.height)
        guard placementFrame.contains(frame) else { return nil }
        return NotchSurfaceFrame(screenIdentifier: screen.identifier, frame: frame)
    }

    private static func isValid(_ screen: ScreenTopology.Screen) -> Bool {
        !screen.identifier.isEmpty && screen.scale > 0 && !screen.frame.isEmpty && !screen.visibleFrame.isEmpty
            && screen.frame.intersects(screen.visibleFrame)
    }

    private static func validPhysicalNotch(on screen: ScreenTopology.Screen) -> CGRect? {
        screen.physicalNotchFrame.flatMap { notch in
            screen.frame.contains(notch) && !notch.isEmpty ? notch : nil
        }
    }
}
