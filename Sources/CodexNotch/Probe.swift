import AppKit
import CodexNotchCore

/// `CodexNotch --probe` prints what the app believes about every display, then exits.
/// Run it first when the island sits in the wrong place on a new machine.
enum Probe {
    static func printReport() {
        print("Codex Notch — display probe")
        print("screens: \(NSScreen.screens.count)")

        for (index, screen) in NSScreen.screens.enumerated() {
            let notchWidth = NotchGeometry.notchWidth(
                screenWidth: screen.frame.width,
                leftWing: screen.auxiliaryTopLeftArea?.width,
                rightWing: screen.auxiliaryTopRightArea?.width
            )
            let metrics = NotchMetrics(
                screenFrame: screen.frame,
                notchWidth: notchWidth,
                notchHeight: max(24, screen.safeAreaInsets.top)
            )
            print("")
            print("[\(index)] \(screen.localizedName)")
            print("  frame        \(screen.frame)")
            print("  safeAreaTop  \(screen.safeAreaInsets.top)")
            print("  auxLeft      \(describe(screen.auxiliaryTopLeftArea))")
            print("  auxRight     \(describe(screen.auxiliaryTopRightArea))")
            print("  notch        \(notchWidth > 0 ? "\(Int(notchWidth))x\(Int(metrics.notchHeight))" : "none → simulated pill")")
            print("  compact      \(NotchGeometry.compactFrame(for: metrics))")
            print("  expanded     \(NotchGeometry.expandedFrame(for: metrics))")
        }

        print("")
        print("codex home   \(AppPaths.codexHome.path)")
        print("sessions     \(AppPaths.codexSessions.path)")
        print("newest       \(SessionLocator.newestRollout(in: AppPaths.codexSessions)?.lastPathComponent ?? "none")")
        print("inbox        \(AppPaths.eventsFile.path)")
    }

    private static func describe(_ rect: NSRect?) -> String {
        guard let rect else { return "nil" }
        return "x=\(Int(rect.minX)) width=\(Int(rect.width))"
    }
}
