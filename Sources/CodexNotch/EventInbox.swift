import Darwin
import Foundation
import CodexNotchCore

/// Watches the append-only inbox that `codexnotch-hook` writes to.
///
/// A file beats a Unix socket here: it survives the app not running, is trivial to
/// inspect (`tail -f`), needs no port or permission, and a single small `write`
/// from the hook is atomic enough for one line.
final class EventInbox {
    private let onEvent: (HookEvent) -> Void
    private let queue = DispatchQueue(label: "io.github.github-bian.CodexNotch.inbox")
    private var source: DispatchSourceFileSystemObject?
    private var offset: UInt64 = 0

    init(onEvent: @escaping (HookEvent) -> Void) {
        self.onEvent = onEvent
    }

    func start() {
        try? AppPaths.ensureSupportDirectory()
        open()
    }

    private func open() {
        source?.cancel()
        source = nil

        let path = AppPaths.eventsFile.path
        let descriptor = path.withCString { Darwin.open($0, O_EVTONLY) }
        guard descriptor >= 0 else { return }

        offset = Self.fileSize(AppPaths.eventsFile)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self, let current = self.source else { return }
            let flags = current.data
            if flags.contains(.delete) || flags.contains(.rename) {
                // The file was rotated away; rebuild after the writer recreates it.
                self.queue.asyncAfter(deadline: .now() + 0.2) { self.open() }
                return
            }
            self.drain()
        }
        source.setCancelHandler { Darwin.close(descriptor) }
        self.source = source
        source.resume()
    }

    private func drain() {
        let url = AppPaths.eventsFile
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        guard size >= offset else {
            offset = 0
            return
        }
        guard size > offset, (try? handle.seek(toOffset: offset)) != nil else { return }
        let data = handle.readDataToEndOfFile()
        offset = size
        guard !data.isEmpty else { return }

        let text = String(decoding: data, as: UTF8.self)
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let event = HookParser.parse(line: String(line)) else { continue }
            DispatchQueue.main.async { [onEvent] in onEvent(event) }
        }
    }

    private static func fileSize(_ url: URL) -> UInt64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
    }
}
