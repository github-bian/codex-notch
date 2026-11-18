import AppKit
import SwiftUI
import CodexNotchCore

/// Owns the panel, its screen placement and the hover/click affordance.
final class NotchController {
    private let model: IslandViewModel
    private let panel = NotchPanel()
    private var hostingView: NSHostingView<IslandView>?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var expandWorkItem: DispatchWorkItem?
    private var collapseWorkItem: DispatchWorkItem?
    private var resizeWorkItem: DispatchWorkItem?

    private let expandDelay: TimeInterval = 0.18
    private let collapseDelay: TimeInterval = 0.32

    init(model: IslandViewModel) {
        self.model = model
    }

    func start() {
        let hosting = NSHostingView(rootView: IslandView(model: model))
        hosting.autoresizingMask = [.width, .height]
        hostingView = hosting
        panel.contentView = hosting

        model.onFrameChange = { [weak self] in self?.applyFrame() }

        refreshDisplay()
        panel.orderFrontRegardless()
        installMouseMonitors()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func stop() {
        cancelExpand()
        cancelCollapse()
        resizeWorkItem?.cancel()
        removeMouseMonitors()
        NotificationCenter.default.removeObserver(self)
        model.onFrameChange = nil
        panel.orderOut(nil)
    }

    // MARK: - Placement

    @objc private func displayParametersChanged() {
        refreshDisplay()
    }

    private func refreshDisplay() {
        model.update(metrics: currentMetrics())
        applyFrame()
    }

    private func applyFrame() {
        let snapshot = model.snapshot
        let height = NotchGeometry.expandedContentHeight(
            hasQuota: snapshot.quota != nil,
            hasReset: snapshot.quota?.resetsAt != nil,
            hasContext: snapshot.contextPercent != nil
        ) + (model.metrics.hasHardwareNotch ? max(0, model.metrics.notchHeight - 24) : 0)
        let frame = model.expanded
            ? NotchGeometry.expandedFrame(for: model.metrics, height: height)
            : NotchGeometry.compactFrame(for: model.metrics)
        resizeWorkItem?.cancel()
        resizeWorkItem = nil
        guard panel.frame != frame else { return }
        if !model.expanded && panel.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            // Keep the carrier large until the SwiftUI shape finishes shrinking.
            let item = DispatchWorkItem { [weak self] in
                guard let self, !self.model.expanded else { return }
                self.resizeWorkItem = nil
                self.setFrame(frame)
            }
            resizeWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: item)
        } else {
            setFrame(frame)
        }
    }

    private func setFrame(_ frame: CGRect) {
        panel.setFrame(frame, display: true)
        hostingView?.frame = CGRect(origin: .zero, size: frame.size)
    }

    private func currentMetrics() -> NotchMetrics {
        let screen = targetScreen()
        guard let screen else { return .fallback }
        let notchWidth = NotchGeometry.notchWidth(
            screenWidth: screen.frame.width,
            leftWing: screen.auxiliaryTopLeftArea?.width,
            rightWing: screen.auxiliaryTopRightArea?.width
        )
        return NotchMetrics(
            screenFrame: screen.frame,
            notchWidth: notchWidth,
            notchHeight: max(24, screen.safeAreaInsets.top)
        )
    }

    private func targetScreen() -> NSScreen? {
        let notched = NSScreen.screens
            .filter { $0.safeAreaInsets.top > 0 }
            .max { $0.safeAreaInsets.top < $1.safeAreaInsets.top }
        return notched ?? NSScreen.main ?? NSScreen.screens.first
    }

    // MARK: - Hover

    private func installMouseMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.pointerMoved()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.pointerMoved()
            return event
        }
    }

    private func removeMouseMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func pointerMoved() {
        let point = NSEvent.mouseLocation
        // When collapsed the hit area is the notch itself; when expanded it is the card.
        let logicalFrame = model.expanded ? panel.frame : NotchGeometry.compactFrame(for: model.metrics)
        let hitFrame = NotchGeometry.hitFrame(panelFrame: logicalFrame, slop: 3)
        let inside = hitFrame.contains(point)

        if inside {
            cancelCollapse()
            guard !model.expanded else { return }
            scheduleExpand()
        } else {
            cancelExpand()
            guard model.expanded, !model.pinned else { return }
            scheduleCollapse()
        }
    }

    private func scheduleExpand() {
        guard expandWorkItem == nil else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.expandWorkItem = nil
            guard !self.model.expanded else { return }
            self.model.setExpanded(true, transient: true)
        }
        expandWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + expandDelay, execute: item)
    }

    private func scheduleCollapse() {
        guard collapseWorkItem == nil else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.collapseWorkItem = nil
            let point = NSEvent.mouseLocation
            guard !NotchGeometry.hitFrame(panelFrame: self.panel.frame, slop: 3).contains(point) else { return }
            self.model.setExpanded(false, transient: true)
        }
        collapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDelay, execute: item)
    }

    private func cancelExpand() {
        expandWorkItem?.cancel()
        expandWorkItem = nil
    }

    private func cancelCollapse() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    // MARK: - Actions

    static func openCodex() {
        guard let url = URL(string: "codex://") else { return }
        NSWorkspace.shared.open(url)
    }

    static func hookCommand() -> String {
        let path = AppPaths.hookExecutableURL.path
        return "notify = [\"\(path)\"]"
    }
}
