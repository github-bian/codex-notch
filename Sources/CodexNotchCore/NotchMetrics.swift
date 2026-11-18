import CoreGraphics
import Foundation

/// Everything the panel needs to know about the display it lives on.
///
/// `notchWidth == 0` means "no hardware notch" (external display, older Mac).
/// The UI still renders, but as a floating pill under the menu bar instead of
/// a simulated island attached to the top edge.
public struct NotchMetrics: Equatable {
    public var screenFrame: CGRect
    public var notchWidth: CGFloat
    public var notchHeight: CGFloat

    public var hasHardwareNotch: Bool { notchWidth > 0 }

    public init(screenFrame: CGRect, notchWidth: CGFloat, notchHeight: CGFloat) {
        self.screenFrame = screenFrame
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
    }

    public static let fallback = NotchMetrics(
        screenFrame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
        notchWidth: 0,
        notchHeight: 24
    )
}

/// Pure layout math. Kept away from AppKit so it can be exercised without a screen.
public enum NotchGeometry {
    public static let minimumNotchWidth: CGFloat = 60
    public static let compactWingWidth: CGFloat = 96
    public static let expandedWidth: CGFloat = 440
    public static let expandedHeight: CGFloat = 196
    public static let simulatedPillWidth: CGFloat = 300
    public static let simulatedPillHeight: CGFloat = 26

    /// macOS reports the two areas beside the notch; what is left is the notch.
    public static func notchWidth(screenWidth: CGFloat, leftWing: CGFloat?, rightWing: CGFloat?) -> CGFloat {
        guard screenWidth > 0,
              let left = leftWing,
              let right = rightWing,
              left > 0,
              right > 0
        else { return 0 }
        let width = (screenWidth - left - right).rounded()
        guard width >= minimumNotchWidth, width <= screenWidth * 0.8 else { return 0 }
        return width
    }

    /// Wings attached to the notch, flush with the top edge.
    public static func compactFrame(for metrics: NotchMetrics) -> CGRect {
        if metrics.hasHardwareNotch {
            return anchoredFrame(
                for: metrics,
                width: metrics.notchWidth + compactWingWidth * 2,
                height: metrics.notchHeight
            )
        }
        return anchoredFrame(for: metrics, width: simulatedPillWidth, height: max(simulatedPillHeight, metrics.notchHeight))
    }

    public static func expandedContentHeight(hasQuota: Bool, hasReset: Bool, hasContext: Bool) -> CGFloat {
        160 + (hasQuota ? (hasReset ? 36 : 23) : 0) - (hasContext ? 0 : 25)
    }

    public static func expandedFrame(for metrics: NotchMetrics, height: CGFloat = expandedHeight) -> CGRect {
        let width = min(expandedWidth, max(320, metrics.screenFrame.width - 80))
        return anchoredFrame(for: metrics, width: width, height: height)
    }

    /// Top-center anchored, clamped inside the display.
    public static func anchoredFrame(for metrics: NotchMetrics, width: CGFloat, height: CGFloat) -> CGRect {
        let screen = metrics.screenFrame
        let clampedWidth = min(width, max(160, screen.width - 16))
        let centred = screen.midX - clampedWidth / 2
        let x = min(max(centred, screen.minX + 8), screen.maxX - clampedWidth - 8)
        let y = screen.maxY - height
        return CGRect(
            x: x.rounded(),
            y: y.rounded(),
            width: clampedWidth.rounded(),
            height: height.rounded()
        )
    }

    /// How far the cursor may stray and still count as "on the island".
    public static func hitFrame(panelFrame: CGRect, slop: CGFloat = 2) -> CGRect {
        panelFrame.insetBy(dx: -slop, dy: -slop)
    }
}
