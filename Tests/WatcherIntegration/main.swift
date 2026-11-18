import Foundation
import CodexNotchCore

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
setenv("CODEX_HOME", root.path, 1)
let sessions = root.appendingPathComponent("sessions/2026/11/18", isDirectory: true)
try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
let firstID = "11111111-1111-1111-1111-111111111111"
let secondID = "22222222-2222-2222-2222-222222222222"
let first = sessions.appendingPathComponent("rollout-first-\(firstID).jsonl")
let second = sessions.appendingPathComponent("rollout-second-\(secondID).jsonl")

func tokenLine(_ total: Int, quota: Bool) -> String {
    let limit = quota ? #","rate_limits":{"primary":{"used_percent":65,"window_minutes":10080}}"# : ""
    return "{\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"total_tokens\":\(total)},\"last_token_usage\":{\"input_tokens\":42},\"model_context_window\":100}\(limit)}}\n"
}

func awaitCondition(_ label: String, seconds: TimeInterval = 3, _ condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition() && Date() < deadline {
        _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
    }
    guard condition() else { fputs("FAIL \(label)\n", stderr); exit(1) }
    print("  ok   \(label)")
}

let start = #"{"type":"event_msg","payload":{"type":"task_started","started_at":1763000000}}"# + "\n"
let project1 = #"{"type":"session_meta","payload":{"cwd":"/tmp/first-project"}}"# + "\n"
try (project1 + start + tokenLine(100, quota: true)).write(to: first, atomically: true, encoding: .utf8)
let model = IslandViewModel()
var resets = 0
let watcher = RolloutWatcher(onReset: { id in
    resets += 1
    model.resetSession(threadID: id)
}, onSignal: { model.apply(signal: $0) })
watcher.start()
defer { watcher.stop() }

awaitCondition("bootstrap selects project and actual quota") {
    model.snapshot.projectName == "first-project" && model.snapshot.totalTokens == 100 && model.snapshot.quota?.remainingPercent == 35
}
let handle = try FileHandle(forWritingTo: first)
try handle.seekToEnd()
let next = Data(tokenLine(200, quota: true).utf8)
let split = next.count / 2
try handle.write(contentsOf: next.prefix(split))
let partialDeadline = Date().addingTimeInterval(1.2)
while Date() < partialDeadline { _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05)) }
guard model.snapshot.totalTokens == 100 else { fputs("FAIL incomplete record was applied\n", stderr); exit(1) }
try handle.write(contentsOf: next.dropFirst(split))
try handle.close()
awaitCondition("incremental reader waits for complete JSONL record") { model.snapshot.totalTokens == 200 }
model.apply(signal: .context(cwd: "/tmp/renamed-project"))
guard model.snapshot.title == "renamed-project" else { fputs("FAIL project title stayed stale\n", stderr); exit(1) }
print("  ok   project title follows a changed working directory")

let project2 = #"{"type":"session_meta","payload":{"cwd":"/tmp/second-project"}}"# + "\n"
try (project2 + start + tokenLine(321, quota: false)).write(to: second, atomically: true, encoding: .utf8)
try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(1)], ofItemAtPath: second.path)
awaitCondition("newest session replaces old project and quota", seconds: 8) {
    resets >= 2 && model.snapshot.projectName == "second-project" && model.snapshot.totalTokens == 321 && model.snapshot.quota == nil
}
try (project2 + start + tokenLine(654, quota: false)).write(to: second, atomically: true, encoding: .utf8)
try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(2)], ofItemAtPath: second.path)
awaitCondition("same-size replaced rollout is reopened", seconds: 8) {
    resets >= 3 && model.snapshot.totalTokens == 654
}
model.apply(hook: HookEvent(kind: .waiting, threadID: firstID, rawType: "approval-requested"))
guard model.snapshot.phase == .running else { fputs("FAIL unrelated hook changed the current session\n", stderr); exit(1) }
model.apply(hook: HookEvent(kind: .waiting, threadID: secondID, rawType: "approval-requested"))
guard model.snapshot.phase == .waiting else { fputs("FAIL matching hook was ignored\n", stderr); exit(1) }
print("  ok   hooks are scoped to the selected session")
model.setExpanded(true, transient: true)
model.apply(hook: HookEvent(kind: .turnCompleted, threadID: secondID, rawType: "agent-turn-complete"))
model.dismiss()
guard model.snapshot.phase == .done else { fputs("FAIL completion disappeared immediately on close\n", stderr); exit(1) }
model.apply(hook: HookEvent(kind: .turnStarted, threadID: secondID, rawType: "agent-turn-start"))
guard model.snapshot.phase == .running else { fputs("FAIL new turn did not cancel completion\n", stderr); exit(1) }
print("  ok   completion remains visible after closing and a new turn cancels its timer")

setenv("CODEX_NOTCH_HOME", root.appendingPathComponent("hook-inbox").path, 1)
var received: [HookEvent.Kind] = []
let inbox = EventInbox { event in
    received.append(event.kind)
    model.apply(hook: event)
}
inbox.start()
defer { inbox.stop() }
let waiting = HookParser.sanitizedLine(#"{"type":"approval-requested","thread-id":"22222222-2222-2222-2222-222222222222"}"#)!
let inboxDeadline = Date().addingTimeInterval(4)
while !received.contains(.waiting) && Date() < inboxDeadline {
    _ = AppPaths.appendEventLine(waiting)
    _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.25))
}
guard received.contains(.waiting), model.snapshot.phase == .waiting else {
    fputs("FAIL hook inbox did not deliver the waiting state\n", stderr); exit(1)
}
print("  ok   hook inbox delivers the selected session's event")
let previousInbox = AppPaths.supportDirectory.appendingPathComponent("previous-events.jsonl")
try FileManager.default.moveItem(at: AppPaths.eventsFile, to: previousInbox)
let failure = HookParser.sanitizedLine(#"{"type":"agent-error","thread-id":"22222222-2222-2222-2222-222222222222"}"#)!
_ = AppPaths.appendEventLine(failure)
awaitCondition("hook inbox reconnects after file rotation", seconds: 4) {
    received.contains(.failed) && model.snapshot.phase == .error
}
