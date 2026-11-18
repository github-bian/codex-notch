import Foundation

/// Restores the latest observable session state without replaying the whole transcript.
public struct RolloutBootstrapResult {
    public let signals: [RolloutSignal]
    public let offset: UInt64
    public let discardPartialLine: Bool
}

public enum RolloutBootstrap {
    private static let tailLimit: UInt64 = 4 * 1024 * 1024
    private static let maxLineBytes = 1024 * 1024
    private static let staleInterval: TimeInterval = 30 * 60

    public static func read(file: URL, now: Date = Date()) throws -> RolloutBootstrapResult {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        let start = size > tailLimit ? size - tailLimit : 0
        var startsMidLine = false
        if start > 0 {
            try handle.seek(toOffset: start - 1)
            startsMidLine = try handle.read(upToCount: 1)?.first != 10
        }
        try handle.seek(toOffset: start)
        let data = try handle.read(upToCount: Int(size - start)) ?? Data()
        let lastNewline = data.lastIndex(of: 10)
        let completeCount = lastNewline.map { data.distance(from: data.startIndex, to: $0) + 1 } ?? 0
        let offset = start + UInt64(completeCount)
        var lines = data.prefix(completeCount).split(separator: 10, omittingEmptySubsequences: true)
        if startsMidLine && !lines.isEmpty { lines.removeFirst() }

        var latestTokens: RolloutSignal?
        var latestContext: RolloutSignal?
        var latestLifecycle: RolloutSignal?
        var lifecycleDate: Date?
        for line in lines.reversed() {
            guard line.count <= maxLineBytes else { continue }
            let candidate = String(decoding: line, as: UTF8.self)
            guard candidate.contains("token_count") || candidate.contains("task_started")
                    || candidate.contains("task_complete") || candidate.contains("turn_aborted")
                    || candidate.contains("task_aborted") || candidate.contains("thread_settings_applied")
                    || candidate.contains("turn_context") || candidate.contains("session_meta") else { continue }
            let bytes = Data(line)
            guard let signal = RolloutParser.parse(data: bytes) else { continue }
            switch signal {
            case .tokens: if latestTokens == nil { latestTokens = signal }
            case .context: if latestContext == nil { latestContext = signal }
            case .taskStarted, .taskCompleted, .turnAborted:
                if latestLifecycle == nil {
                    latestLifecycle = signal
                    lifecycleDate = eventDate(bytes)
                }
            }
            if latestTokens != nil && latestContext != nil && latestLifecycle != nil { break }
        }

        // A long turn may put its project metadata before the bounded tail.
        if latestContext == nil && start > 0 {
            try handle.seek(toOffset: 0)
            let header = try handle.read(upToCount: maxLineBytes) ?? Data()
            if let newline = header.firstIndex(of: 10) {
                let firstLine = header.prefix(upTo: newline)
                if case let .context(cwd)? = RolloutParser.parse(data: Data(firstLine)) {
                    latestContext = .context(cwd: cwd)
                }
            }
        }

        var signals: [RolloutSignal] = []
        if let latestContext { signals.append(latestContext) }
        if let latestTokens { signals.append(latestTokens) }
        let modified = (try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate]) as? Date
        let stale = modified.map { now.timeIntervalSince($0) > staleInterval } ?? true
        if let lifecycle = latestLifecycle {
            switch lifecycle {
            case .taskStarted where stale:
                signals.append(.turnAborted)
            case .taskCompleted where lifecycleDate.map({ now.timeIntervalSince($0) > 8 }) ?? true:
                signals.append(.turnAborted)
            default:
                signals.append(lifecycle)
            }
        } else if latestTokens != nil && stale {
            signals.append(.turnAborted)
        }

        // If a single line exceeds the whole scan window, ignore its continuation.
        let discardPartial = completeCount == 0 && start > 0
        return RolloutBootstrapResult(signals: signals, offset: discardPartial ? size : offset, discardPartialLine: discardPartial)
    }

    private static func eventDate(_ data: Data) -> Date? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let stamp = root["timestamp"] as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: stamp) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: stamp)
    }
}
