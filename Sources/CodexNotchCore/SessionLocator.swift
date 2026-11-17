import Foundation

public enum SessionLocator {
    /// Newest `rollout-*.jsonl` under a sessions root.
    ///
    /// The directory tree is one folder per day (`sessions/2026/11/17/...`), so a
    /// full enumeration is cheap but not free — callers should cache the result and
    /// only rescan when the current file goes quiet.
    public static func newestRollout(
        in root: URL,
        fileManager: FileManager = .default
    ) -> URL? {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }

        var newest: (url: URL, date: Date)?
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate
            else { continue }
            if let current = newest, modified <= current.date { continue }
            // Only rollouts: `archived_sessions` and other jsonl files are not live.
            guard url.lastPathComponent.hasPrefix("rollout-") else { continue }
            newest = (url, modified)
        }
        return newest?.url
    }

    /// `.../sessions/2026/11/17/rollout-...jsonl` -> `2026-11-17`
    public static func dayFolder(of rollout: URL) -> String? {
        let parts = rollout.deletingLastPathComponent().pathComponents
        guard parts.count >= 3 else { return nil }
        let year = parts[parts.count - 3]
        let month = parts[parts.count - 2]
        let day = parts[parts.count - 1]
        guard year.count == 4, month.count == 2, day.count == 2 else { return nil }
        return "\(year)-\(month)-\(day)"
    }
}
