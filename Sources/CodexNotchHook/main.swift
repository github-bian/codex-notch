import Foundation
import CodexNotchCore

/// The command Codex calls through `notify = [...]`.
///
/// Codex hands the payload JSON as the last argument. We only forward it: parsing the
/// payload here would mean re-learning Codex's schema in two places.
let arguments = CommandLine.arguments.dropFirst()

if arguments.contains("--print-config") {
    print("notify = [\"\(AppPaths.hookExecutableURL.path)\"]")
    exit(0)
}

if arguments.contains("--events-path") {
    print(AppPaths.eventsFile.path)
    exit(0)
}

var payload = arguments.first ?? ""
if payload.isEmpty {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    payload = String(decoding: data, as: UTF8.self)
}

let line = payload
    .replacingOccurrences(of: "\n", with: " ")
    .replacingOccurrences(of: "\r", with: " ")
    .trimmingCharacters(in: .whitespacesAndNewlines)

// A hook must never break the turn it is reporting on: exit 0 even when the app is
// not running. The payload stays on disk and is picked up when it starts.
guard !line.isEmpty else { exit(0) }
_ = AppPaths.appendEventLine(line)
exit(0)
