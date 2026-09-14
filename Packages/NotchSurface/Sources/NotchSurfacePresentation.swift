import NotchDomain
import Observation
import SwiftUI

enum NotchSurfaceMetrics {
    static let compactSize = CGSize(width: 220, height: 52)
    static let closedTopShoulderRadius: CGFloat = 6
    static let closedBottomCornerRadius: CGFloat = 14
    static let openedTopShoulderRadius: CGFloat = 19
    static let openedBottomCornerRadius: CGFloat = 24
}

@MainActor
@Observable
final class NotchSurfacePresentationModel {
    private(set) var snapshot = SurfaceSnapshot()
    private(set) var collapsedSize = NotchSurfaceGeometry.fallbackCollapsedSize
    private(set) var isExpandedGeometry = false
    private(set) var isCompactGeometry = false
    var isHovering = false
    var debugLabel: String?

    func apply(_ snapshot: SurfaceSnapshot, collapsedSize: CGSize? = nil) {
        self.snapshot = snapshot
        if let collapsedSize { self.collapsedSize = collapsedSize }
    }

    func projectCollapsed(collapsedSize: CGSize) {
        isExpandedGeometry = false
        isCompactGeometry = false
        self.collapsedSize = collapsedSize
    }

    func projectCompact() {
        isExpandedGeometry = false
        isCompactGeometry = true
    }

    func projectExpanded(collapsedSize: CGSize? = nil) {
        isExpandedGeometry = true
        isCompactGeometry = false
        if let collapsedSize { self.collapsedSize = collapsedSize }
    }

    var visibleSurfaceSize: CGSize {
        if isExpandedGeometry { return SurfaceExpansionContract.surfaceSize }
        if isCompactGeometry { return NotchSurfaceMetrics.compactSize }
        return collapsedSize
    }

    var topShoulderRadius: CGFloat {
        isExpandedGeometry
            ? NotchSurfaceMetrics.openedTopShoulderRadius
            : NotchSurfaceMetrics.closedTopShoulderRadius
    }

    var bottomCornerRadius: CGFloat {
        isExpandedGeometry
            ? NotchSurfaceMetrics.openedBottomCornerRadius
            : NotchSurfaceMetrics.closedBottomCornerRadius
    }
}

struct NotchSurfaceShape: Shape {
    var topShoulderRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topShoulderRadius, bottomCornerRadius) }
        set {
            topShoulderRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let shoulder = min(max(topShoulderRadius, 0), rect.height * 0.45)
        let bottom = min(max(bottomCornerRadius, 0), rect.height * 0.45)
        let leftWall = rect.minX + shoulder
        let rightWall = rect.maxX - shoulder
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: leftWall, y: rect.minY + shoulder),
            control1: CGPoint(x: rect.minX + shoulder * 0.62, y: rect.minY),
            control2: CGPoint(x: leftWall, y: rect.minY + shoulder * 0.38)
        )
        path.addLine(to: CGPoint(x: leftWall, y: rect.maxY - bottom))
        path.addCurve(
            to: CGPoint(x: leftWall + bottom, y: rect.maxY),
            control1: CGPoint(x: leftWall, y: rect.maxY - bottom * 0.30),
            control2: CGPoint(x: leftWall + bottom * 0.30, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rightWall - bottom, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rightWall, y: rect.maxY - bottom),
            control1: CGPoint(x: rightWall - bottom * 0.30, y: rect.maxY),
            control2: CGPoint(x: rightWall, y: rect.maxY - bottom * 0.30)
        )
        path.addLine(to: CGPoint(x: rightWall, y: rect.minY + shoulder))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: CGPoint(x: rightWall, y: rect.minY + shoulder * 0.38),
            control2: CGPoint(x: rect.maxX - shoulder * 0.62, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

/// Native hit-testing for the visible surface, excluding its host and shadow envelope.
public enum NotchSurfaceHitTesting {
    public static func contains(
        point: CGPoint,
        hostSize: CGSize,
        surfaceSize: CGSize,
        topShoulderRadius: CGFloat,
        bottomCornerRadius: CGFloat
    ) -> Bool {
        guard hostSize.width >= surfaceSize.width, hostSize.height >= surfaceSize.height else { return false }
        let surfaceRect = CGRect(
            x: (hostSize.width - surfaceSize.width) / 2, y: 0,
            width: surfaceSize.width, height: surfaceSize.height)
        guard surfaceRect.contains(point) else { return false }
        return NotchSurfaceShape(
            topShoulderRadius: topShoulderRadius,
            bottomCornerRadius: bottomCornerRadius
        ).path(in: surfaceRect).contains(point)
    }
}

struct NotchSurfaceRootView: View {
    @Bindable var model: NotchSurfacePresentationModel
    let send: (SurfaceIntent) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isAccessibilityFocused: Bool

    private var isExpanded: Bool { model.isExpandedGeometry }

    private var accessibilityState: String {
        isExpanded ? "expanded" : model.isCompactGeometry ? "compact" : "collapsed"
    }

    var body: some View {
        let shape = NotchSurfaceShape(
            topShoulderRadius: model.topShoulderRadius,
            bottomCornerRadius: model.bottomCornerRadius
        )
        ZStack(alignment: .top) {
            shape.fill(.black)
            if isExpanded {
                VStack(spacing: 8) {
                    Text("NotchHub").font(.headline)
                    Text("Surface ready").font(.subheadline).foregroundStyle(.secondary)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
                .transition(.scale(scale: 0.8, anchor: .top).combined(with: .opacity))
            } else if model.isCompactGeometry {
                Text("Surface ready")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Rectangle()
                .fill(.black)
                .frame(height: 1)
                .padding(.horizontal, model.topShoulderRadius)
                .frame(maxHeight: .infinity, alignment: .top)
            if let debugLabel = model.debugLabel {
                Text(verbatim: debugLabel)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.green)
                    .padding(4)
                    .background(.black.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .accessibilityLabel("F2 surface debug overlay")
            }
        }
        .frame(width: model.visibleSurfaceSize.width, height: model.visibleSurfaceSize.height, alignment: .top)
        .clipShape(shape)
        .overlay {
            shape
                .fill(.clear)
                .contentShape(shape)
                .onHover(perform: handleHover)
                .onTapGesture { send(.clicked) }
                .accessibilityHidden(true)
        }
        .shadow(color: isExpanded || model.isHovering ? .black.opacity(0.7) : .clear, radius: 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityLabel("NotchHub \(accessibilityState) surface")
        .accessibilityValue(Text(accessibilityState.capitalized))
        .accessibilityHint(
            Text(
                isExpanded
                    ? "Use Tab to move through controls. Press Escape to collapse." : "Not interactive while collapsed."
            )
        )
        .accessibilityHidden(!isExpanded)
        .accessibilityElement(children: isExpanded ? .contain : .ignore)
        .accessibilityFocused($isAccessibilityFocused)
        .onChange(of: isAccessibilityFocused) { _, focused in
            send(focused ? .accessibilityInteractionBegan : .accessibilityInteractionEnded)
        }
        .animation(surfaceAnimation, value: model.visibleSurfaceSize)
    }

    private var surfaceAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : isExpanded
                ? .spring(response: 0.42, dampingFraction: 0.80)
                : .spring(response: 0.45, dampingFraction: 1.00)
    }

    private func handleHover(_ hovering: Bool) {
        model.isHovering = hovering
        send(
            hovering
                ? (isExpanded ? .expandedHoverEntered : .hoverEntered)
                : (isExpanded ? .expandedHoverExited : .hoverExited))
    }
}
