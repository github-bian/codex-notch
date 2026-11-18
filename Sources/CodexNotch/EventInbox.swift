import Darwin
import Foundation
import CodexNotchCore

/// Watches the optional, local append-only hook inbox.
final class EventInbox {
    private let onEvent: (HookEvent) -> Void
    private let queue = DispatchQueue(label: "io.github.github-bian.CodexNotch.inbox")
    private var source: DispatchSourceFileSystemObject?
    private var offset: UInt64 = 0
    private var lines = JSONLBuffer()
    private var running = false
    private var firstOpen = true

    init(onEvent: @escaping (HookEvent) -> Void) {
        self.onEvent = onEvent
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.running = true
            _ = try? AppPaths.ensureSupportDirectory()
            self.open()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.running = false
            self?.source?.cancel()
            self?.source = nil
        }
    }

    private func open() {
        guard running else { return }
        source?.cancel()
        source = nil
        let descriptor = AppPaths.eventsFile.path.withCString { Darwin.open($0, O_EVTONLY) }
        guard descriptor >= 0 else {
            queue.asyncAfter(deadline: .now() + 1) { [weak self] in self?.open() }
            return
        }
        offset = firstOpen ? Self.fileSize(AppPaths.eventsFile) : 0
        firstOpen = false
        lines = JSONLBuffer()
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .extend, .delete, .rename], queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self, let current = self.source else { return }
            if current.data.contains(.delete) || current.data.contains(.rename) {
                current.cancel()
                self.source = nil
                self.queue.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.open() }
            } else {
                self.drain()
            }
        }
        source.setCancelHandler { Darwin.close(descriptor) }
        self.source = source
        source.resume()
        drain()
    }

    private func drain() {
        guard let handle = try? FileHandle(forReadingFrom: AppPaths.eventsFile) else { return }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return }
        if size < offset {
            offset = 0
            lines = JSONLBuffer()
        }
        guard size > offset, (try? handle.seek(toOffset: offset)) != nil else { return }
        while offset < size {
            guard let data = try? handle.read(upToCount: 1024 * 1024), !data.isEmpty else { break }
            offset += UInt64(data.count)
            for line in lines.append(data) {
                guard let event = HookParser.parse(data: line) else { continue }
                DispatchQueue.main.async { [onEvent] in onEvent(event) }
            }
        }
    }

    private static func fileSize(_ url: URL) -> UInt64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
    }
}
