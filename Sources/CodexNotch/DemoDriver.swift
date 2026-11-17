import Foundation
import CodexNotchCore

/// Drives the island with plausible fake data so the geometry and motion can be
/// judged without waiting for a real Codex turn (`--demo`).
final class DemoDriver {
    private let model: IslandViewModel
    private var timer: Timer?
    private var step = 0

    init(model: IslandViewModel) {
        self.model = model
    }

    func start() {
        apply(step: 0)
        let timer = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.step = (self.step + 1) % 5
            self.apply(step: self.step)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func apply(step: Int) {
        var snapshot = IslandSnapshot(
            phase: .running,
            title: "codex-notch",
            projectName: "codex-notch",
            startedAt: Date().addingTimeInterval(-320),
            totalTokens: 128_400,
            contextUsedTokens: 42_000,
            contextWindowTokens: 258_400,
            quota: QuotaSnapshot(
                usedPercent: 38,
                windowMinutes: 300,
                resetsAt: Date().addingTimeInterval(2 * 3_600 + 14 * 60),
                planType: "plus"
            )
        )

        switch step {
        case 1:
            snapshot.phase = .waiting
            snapshot.note = "approval requested"
        case 2:
            snapshot.phase = .done
            snapshot.note = nil
        case 3:
            snapshot = .idle
        default:
            break
        }

        model.applyForDemo(snapshot)
    }
}
