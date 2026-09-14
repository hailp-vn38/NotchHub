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

/// Selects only the built-in display and keeps every result below the menu bar.
public enum NotchSurfaceGeometry {
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

        let usableFrame = screen.visibleFrame.intersection(screen.frame)
        let size = CGSize(
            width: min(preferredSize.width, usableFrame.width),
            height: min(preferredSize.height, usableFrame.height)
        )
        guard size.width > 0, size.height > 0 else { return nil }

        let validNotch = screen.physicalNotchFrame.flatMap { notch in
            screen.frame.contains(notch) && !notch.isEmpty ? notch : nil
        }
        let anchorX = validNotch?.midX ?? usableFrame.midX
        let originX = min(max(anchorX - size.width / 2, usableFrame.minX), usableFrame.maxX - size.width)
        let anchorTop = min(validNotch?.minY ?? usableFrame.maxY, usableFrame.maxY)
        let originY = max(usableFrame.minY, anchorTop - size.height)
        let frame = CGRect(origin: CGPoint(x: originX, y: originY), size: size)
        guard usableFrame.contains(frame) else { return nil }

        return NotchSurfaceFrame(screenIdentifier: screen.identifier, frame: frame)
    }

    private static func fixedFrame(
        for size: CGSize,
        on screen: ScreenTopology.Screen
    ) -> NotchSurfaceFrame? {
        guard size.width > 0, size.height > 0 else { return nil }
        let usableFrame = screen.visibleFrame.intersection(screen.frame)
        guard usableFrame.width >= size.width, usableFrame.height >= size.height else { return nil }
        let validNotch = screen.physicalNotchFrame.flatMap { notch in
            screen.frame.contains(notch) && !notch.isEmpty ? notch : nil
        }
        let anchorX = validNotch?.midX ?? usableFrame.midX
        let originX = anchorX - size.width / 2
        let anchorTop = min(validNotch?.minY ?? usableFrame.maxY, usableFrame.maxY)
        let frame = CGRect(x: originX, y: anchorTop - size.height, width: size.width, height: size.height)
        guard usableFrame.contains(frame) else { return nil }
        return NotchSurfaceFrame(screenIdentifier: screen.identifier, frame: frame)
    }

    private static func isValid(_ screen: ScreenTopology.Screen) -> Bool {
        !screen.identifier.isEmpty && screen.scale > 0 && !screen.frame.isEmpty && !screen.visibleFrame.isEmpty
            && screen.frame.intersects(screen.visibleFrame)
    }
}
