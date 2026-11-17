import Foundation

public enum AppPaths {
    public static let appSupportFolderName = "CodexNotch"
    public static let eventsFileName = "events.jsonl"

    /// Overridable so tests and the installer never touch the real inbox.
    public static var supportDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["CODEX_NOTCH_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(appSupportFolderName, isDirectory: true)
    }

    public static var eventsFile: URL {
        supportDirectory.appendingPathComponent(eventsFileName)
    }

    public static var codexHome: URL {
        if let override = ProcessInfo.processInfo.environment["CODEX_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
    }

    public static var codexSessions: URL {
        codexHome.appendingPathComponent("sessions", isDirectory: true)
    }

    @discardableResult
    public static func ensureSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: eventsFile.path) {
            fileManager.createFile(atPath: eventsFile.path, contents: nil)
        }
        return supportDirectory
    }

    /// Appends one line for the running app to pick up. Never throws to the caller:
    /// a hook that fails must not break the Codex turn it is reporting on.
    @discardableResult
    public static func appendEventLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            try ensureSupportDirectory()
            let handle = try FileHandle(forWritingTo: eventsFile)
            defer { try? handle.close() }
            try handle.seekToEnd()
            if let data = (trimmed + "\n").data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
            return true
        } catch {
            return false
        }
    }

    /// `~/project/foo` -> `foo`; never the full path, the wings are 96pt wide.
    public static func projectName(from cwd: String?) -> String? {
        guard let cwd, !cwd.isEmpty else { return nil }
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? nil : name
    }

    /// The helper that ships next to the app binary.
    public static var hookExecutableURL: URL {
        let bundle = Bundle.main
        if let path = bundle.executableURL?.deletingLastPathComponent()
            .appendingPathComponent("codexnotch-hook") {
            return path
        }
        return URL(fileURLWithPath: CommandLine.arguments.first ?? "CodexNotch")
            .deletingLastPathComponent()
            .appendingPathComponent("codexnotch-hook")
    }
}
