import Foundation
import CodexNotchCore

/// Serial background reader: follow the newest rollout without blocking the UI.
final class RolloutWatcher {
    private let onReset: (String?) -> Void
    private let onSignal: (RolloutSignal) -> Void
    private let queue = DispatchQueue(label: "io.github.github-bian.CodexNotch.rollout")
    private var timer: Timer?
    private var currentFile: URL?
    private var currentFileNumber: UInt64?
    private var offset: UInt64 = 0
    private var lines = JSONLBuffer()
    private var staleNotified = false
    private var lastScan = Date.distantPast
    private static let rescanInterval: TimeInterval = 5
    private static let readLimit = 1024 * 1024

    init(onReset: @escaping (String?) -> Void, onSignal: @escaping (RolloutSignal) -> Void) {
        self.onReset = onReset
        self.onSignal = onSignal
    }

    func start() {
        queue.async { [weak self] in self?.tick() }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.queue.async { [weak self] in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        if currentFile == nil || Date().timeIntervalSince(lastScan) >= Self.rescanInterval {
            rescan()
        }
        readNewBytes()
        checkStale()
    }

    private func rescan() {
        lastScan = Date()
        guard let file = SessionLocator.newestRollout(in: AppPaths.codexSessions) else { return }
        let fileNumber = ((try? FileManager.default.attributesOfItem(atPath: file.path)[.systemFileNumber]) as? NSNumber)?.uint64Value
        guard file != currentFile || fileNumber != currentFileNumber,
              let bootstrap = try? RolloutBootstrap.read(file: file) else { return }
        currentFile = file
        currentFileNumber = fileNumber
        offset = bootstrap.offset
        lines = JSONLBuffer(discardFirstLine: bootstrap.discardPartialLine)
        staleNotified = false
        let candidate = String(file.deletingPathExtension().lastPathComponent.suffix(36))
        let threadID = UUID(uuidString: candidate)?.uuidString
        DispatchQueue.main.async { [onReset, onSignal] in
            onReset(threadID)
            bootstrap.signals.forEach(onSignal)
        }
    }

    private func readNewBytes() {
        guard let file = currentFile,
              let handle = try? FileHandle(forReadingFrom: file) else { return }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return }
        if size < offset {
            currentFile = nil
            lines = JSONLBuffer()
            rescan()
            return
        }
        guard size > offset, (try? handle.seek(toOffset: offset)) != nil else { return }
        var signals: [RolloutSignal] = []
        var readBytes = 0
        while offset < size && readBytes < 4 * Self.readLimit {
            let count = min(Self.readLimit, Int(size - offset))
            guard let data = try? handle.read(upToCount: count), !data.isEmpty else { break }
            offset += UInt64(data.count)
            readBytes += data.count
            staleNotified = false
            for line in lines.append(data) {
                if let signal = RolloutParser.parse(data: line) { signals.append(signal) }
            }
        }
        guard !signals.isEmpty else { return }
        DispatchQueue.main.async { [onSignal] in signals.forEach(onSignal) }
    }

    private func checkStale() {
        guard !staleNotified, let file = currentFile,
              let modified = (try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate]) as? Date,
              Date().timeIntervalSince(modified) > 30 * 60 else { return }
        staleNotified = true
        DispatchQueue.main.async { [onSignal] in onSignal(.turnAborted) }
    }
}
