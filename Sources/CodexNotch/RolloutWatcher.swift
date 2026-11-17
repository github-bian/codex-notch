import Foundation
import CodexNotchCore

/// Tails the newest Codex rollout and turns new lines into signals.
///
/// This is the passive channel: it works with zero configuration. The active channel
/// (`EventInbox`, fed by `codexnotch-hook` from Codex's `notify`) is what makes the
/// island react instantly instead of on the next poll.
final class RolloutWatcher {
    private let onSignal: (RolloutSignal) -> Void
    private var timer: Timer?
    private var currentFile: URL?
    private var offset: UInt64 = 0
    private var pending = ""
    private var dropFirstLine = false
    private var lastScan = Date.distantPast

    private static let tailWindow: UInt64 = 64 * 1024
    private static let rescanInterval: TimeInterval = 30

    init(onSignal: @escaping (RolloutSignal) -> Void) {
        self.onSignal = onSignal
    }

    func start() {
        rescan()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        if currentFile == nil || Date().timeIntervalSince(lastScan) > Self.rescanInterval {
            rescan()
        }
        readNewBytes()
    }

    private func rescan() {
        lastScan = Date()
        guard let file = SessionLocator.newestRollout(in: AppPaths.codexSessions) else { return }
        guard file != currentFile else { return }
        currentFile = file
        let size = Self.fileSize(file)
        // Start from the tail: history is not interesting, the current turn is.
        offset = size > Self.tailWindow ? size - Self.tailWindow : 0
        pending = ""
        dropFirstLine = offset > 0
    }

    private func readNewBytes() {
        guard let file = currentFile else { return }
        let size = Self.fileSize(file)
        if size < offset {
            // Truncated or replaced.
            offset = 0
            pending = ""
            dropFirstLine = false
        }
        guard size > offset else { return }
        guard let handle = try? FileHandle(forReadingFrom: file) else { return }
        defer { try? handle.close() }
        guard (try? handle.seek(toOffset: offset)) != nil else { return }
        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty else { return }
        offset += UInt64(data.count)

        pending += String(decoding: data, as: UTF8.self)
        var lines = pending.components(separatedBy: "\n")
        pending = lines.removeLast() // incomplete tail, keep for the next tick
        if dropFirstLine {
            if !lines.isEmpty { lines.removeFirst() }
            dropFirstLine = false
        }
        guard !lines.isEmpty else { return }

        var signals: [RolloutSignal] = []
        for line in lines where !line.isEmpty {
            if let signal = RolloutParser.parse(line: line) {
                signals.append(signal)
            }
        }
        guard !signals.isEmpty else { return }
        DispatchQueue.main.async { [onSignal] in
            signals.forEach(onSignal)
        }
    }

    private static func fileSize(_ url: URL) -> UInt64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
    }
}
