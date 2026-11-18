import Foundation
import CodexNotchCore

/// The command Codex calls through `notify = [...]`.
///
/// Codex hands the payload JSON as the last argument. Only lifecycle metadata is stored.
let arguments = CommandLine.arguments.dropFirst()

if arguments.contains("--print-config") {
    print("notify = [\"\(AppPaths.hookExecutableURL.path)\"]")
    exit(0)
}

if arguments.contains("--events-path") {
    print(AppPaths.eventsFile.path)
    exit(0)
}

var payload = arguments.last ?? ""
if payload.isEmpty {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    payload = String(decoding: data, as: UTF8.self)
}

// Never write prompt or response text, and never block the Codex turn on failure.
guard let line = HookParser.sanitizedLine(payload) else { exit(0) }
_ = AppPaths.appendEventLine(line)
exit(0)
