import Foundation
import Combine
import CodexNotchCore

/// Owns the single snapshot the island draws.
///
/// All mutation happens on the main thread: watchers hop here before calling `apply`.
final class IslandViewModel: ObservableObject {
    let isDemo = CommandLine.arguments.contains("--demo")
    @Published private(set) var snapshot: IslandSnapshot = .idle
    @Published private(set) var metrics: NotchMetrics = .fallback
    @Published var expanded = false
    @Published var pinned = false

    /// Called when the panel has to change size (expand / collapse / screen change).
    var onFrameChange: (() -> Void)?

    private var hideWorkItem: DispatchWorkItem?
    private var selectedThreadID: String?

    // MARK: - Inputs

    func resetSession(threadID: String?) {
        selectedThreadID = threadID
        cancelHide()
        snapshot = .idle
        if expanded { onFrameChange?() }
    }

    func update(metrics: NotchMetrics) {
        guard metrics != self.metrics else { return }
        self.metrics = metrics
        onFrameChange?()
    }

    func apply(signal: RolloutSignal) {
        switch signal {
        case let .taskStarted(_, startedAt):
            snapshot.phase = .running
            snapshot.startedAt = startedAt
            snapshot.lastActivityAt = Date()
            snapshot.note = nil
            cancelHide()

        case let .tokens(token):
            snapshot.totalTokens = token.totalTokens
            snapshot.contextUsedTokens = token.contextUsedTokens
            snapshot.contextWindowTokens = token.contextWindowTokens
            snapshot.quota = token.quota
            snapshot.lastActivityAt = Date()
            if snapshot.phase == .idle {
                snapshot.phase = .running
                snapshot.startedAt = nil
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
        if expanded { onFrameChange?() }
    }

    func apply(hook: HookEvent) {
        if let selectedThreadID, let eventThreadID = hook.threadID,
           selectedThreadID.caseInsensitiveCompare(eventThreadID) != .orderedSame { return }
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
        if expanded { onFrameChange?() }
    }

    /// Demo seam: replaces the whole snapshot without replaying event semantics.
    func applyForDemo(_ snapshot: IslandSnapshot) {
        self.snapshot = snapshot
        if expanded { onFrameChange?() }
    }

    // MARK: - Interaction

    /// Click on the collapsed wings: pin it open (or close if already pinned).
    func togglePinned() {
        pinned.toggle()
        expanded = pinned
        if expanded { cancelHide() }
        onFrameChange?()
        if !pinned { maybeAutoHide() }
    }

    /// Hover produces a transient expansion that never outlives the cursor.
    func setExpanded(_ value: Bool, transient: Bool) {
        guard expanded != value else { return }
        expanded = value
        if !value && transient { pinned = false }
        if value { cancelHide() }
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
        guard !pinned, !expanded else { return }
        let item = DispatchWorkItem { [weak self] in
            self?.hideWorkItem = nil
            guard let self, !self.pinned, !self.expanded else { return }
            self.snapshot.phase = .idle
            self.snapshot.note = nil
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func maybeAutoHide() {
        guard !pinned, !expanded else { return }
        switch snapshot.phase {
        case .done: scheduleHide(after: 8)
        case .error: scheduleHide(after: 15)
        default: break
        }
    }

    private func cancelHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    private func applyProject(cwd: String) {
        guard let name = AppPaths.projectName(from: cwd) else { return }
        let titleTracksProject = snapshot.title == nil || snapshot.title?.isEmpty == true || snapshot.title == snapshot.projectName
        snapshot.projectName = name
        if titleTracksProject { snapshot.title = name }
    }
}
