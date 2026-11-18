import Foundation

/// Keeps complete UTF-8 lines intact across reads and bounds oversized records.
public struct JSONLBuffer {
    private var pending = Data()
    private var discarding = false
    private let maxLineBytes: Int

    public init(maxLineBytes: Int = 1024 * 1024, discardFirstLine: Bool = false) {
        self.maxLineBytes = maxLineBytes
        self.discarding = discardFirstLine
    }

    public mutating func append(_ data: Data) -> [Data] {
        pending.append(data)
        var lines: [Data] = []
        while let newline = pending.firstIndex(of: 10) {
            let line = pending.prefix(upTo: newline)
            if !discarding && line.count <= maxLineBytes && !line.isEmpty {
                lines.append(Data(line))
            }
            discarding = false
            pending.removeSubrange(...newline)
        }
        if pending.count > maxLineBytes {
            pending.removeAll(keepingCapacity: false)
            discarding = true
        }
        return lines
    }
}
