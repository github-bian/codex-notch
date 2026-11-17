import Foundation
import Combine
import CodexNotchCore

/// Owns the single snapshot the island draws.
///
/// All mutation happens on the main thread: watchers hop here before calling `apply`.
final class IslandViewModel: ObservableObject {
    @Published private(set) var snapshot: IslandSnapshot = .idle
    @Published private(set) var metrics: NotchMetrics = .fallback
    @Published var expanded = false
    @Published var pinned = false

    /// Called when the panel has to change size (expand / collapse / screen change).
    var onFrameChange: (() -> Void)?

    private var hideWorkItem: DispatchWorkItem?

    // MARK: - Inputs

    func update(metrics: NotchMetrics) {
        guard metrics != self.metrics else { return }
        self.metrics = metrics
        onFrameChange?()
    }

    func apply(signal: RolloutSignal) {
        switch signal {
        case let .taskStarted(_, startedAt):
            snapshot.phase = .running
            snapshot.startedAt = startedAt ?? Date()
            snapshot.lastActivityAt = Date()
            snapshot.note = nil
            cancelHide()

        case let .tokens(token):
            snapshot.totalTokens = token.totalTokens
            snapshot.contextUsedTokens = token.contextUsedTokens
            snapshot.contextWindowTokens = token.contextWindowTokens
            if let quota = token.quota { snapshot.quota = quota }
            snapshot.lastActivityAt = Date()
            if snapshot.phase == .idle {
                snapshot.phase = .running
                snapshot.startedAt = snapshot.startedAt ?? Date()
            }

        case let .taskCompleted(turnID, _):
            snapshot.phase = .done
            snapshot.note = turnID.map { "turn \($0.prefix(8))" }
            snapshot.lastActivityAt = Date()
            scheduleHide(after: 8)

        case .turnAborted:
            snapshot.phase = .idle
            snapshot.note = nil
            cancelHide()

        case let .context(cwd):
            applyProject(cwd: cwd)
        }
    }

    func apply(hook: HookEvent) {
        switch hook.kind {
        case .turnStarted:
            snapshot.phase = .running
            snapshot.startedAt = Date()
            snapshot.lastActivityAt = Date()
            snapshot.note = nil
            cancelHide()
        case .waiting:
            snapshot.phase = .waiting
            snapshot.note = "approval requested"
            snapshot.lastActivityAt = Date()
            cancelHide()
        case .turnCompleted:
            snapshot.phase = .done
            snapshot.note = nil
            snapshot.lastActivityAt = Date()
            scheduleHide(after: 8)
        case .failed:
            snapshot.phase = .error
            snapshot.note = hook.message
            snapshot.lastActivityAt = Date()
            scheduleHide(after: 15)
        case .notice:
            snapshot.note = hook.message
        }
        if let cwd = hook.cwd { applyProject(cwd: cwd) }
    }

    /// Demo seam: replaces the whole snapshot without replaying event semantics.
    func applyForDemo(_ snapshot: IslandSnapshot) {
        self.snapshot = snapshot
    }

    // MARK: - Interaction

    /// Click on the collapsed wings: pin it open (or close if already pinned).
    func togglePinned() {
        pinned.toggle()
        expanded = pinned
        onFrameChange?()
        if !pinned { maybeAutoHide() }
    }

    /// Hover produces a transient expansion that never outlives the cursor.
    func setExpanded(_ value: Bool, transient: Bool) {
        guard expanded != value else { return }
        expanded = value
        if !value && transient { pinned = false }
        onFrameChange?()
        if !value { maybeAutoHide() }
    }

    func dismiss() {
        pinned = false
        expanded = false
        onFrameChange?()
        maybeAutoHide()
    }

    // MARK: - Auto-hide

    private func scheduleHide(after seconds: TimeInterval) {
        cancelHide()
        let item = DispatchWorkItem { [weak self] in
            self?.hideWorkItem = nil
            self?.maybeAutoHide()
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func maybeAutoHide() {
        guard !pinned, !expanded else { return }
        guard snapshot.phase == .done || snapshot.phase == .error else { return }
        snapshot.phase = .idle
        snapshot.note = nil
    }

    private func cancelHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    private func applyProject(cwd: String) {
        guard let name = AppPaths.projectName(from: cwd) else { return }
        snapshot.projectName = name
        if snapshot.title == nil || snapshot.title?.isEmpty == true {
            snapshot.title = name
        }
    }
}
