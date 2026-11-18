import CoreGraphics
import Foundation
import CodexNotchCore

// XCTest is not part of the Command Line Tools, so this target is a plain
// executable: it prints one line per check and exits non-zero on failure.

var failures = 0
var checks = 0

func expect(_ condition: Bool, _ label: String) {
    checks += 1
    if condition {
        print("  ok   \(label)")
    } else {
        failures += 1
        print("  FAIL \(label)")
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
    checks += 1
    if actual == expected {
        print("  ok   \(label)")
    } else {
        failures += 1
        print("  FAIL \(label)\n       expected: \(expected)\n       actual:   \(actual)")
    }
}

func section(_ name: String) {
    print("\n\(name)")
}

// MARK: - Geometry

section("geometry")
let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)

expectEqual(NotchGeometry.notchWidth(screenWidth: 1728, leftWing: 759, rightWing: 759), 210, "notch = screen - wings")
expectEqual(NotchGeometry.notchWidth(screenWidth: 1728, leftWing: nil, rightWing: nil), 0, "no auxiliary areas -> no notch")
expectEqual(NotchGeometry.notchWidth(screenWidth: 1728, leftWing: 860, rightWing: 860), 0, "implausibly narrow notch rejected")
expectEqual(NotchGeometry.notchWidth(screenWidth: 1728, leftWing: 0, rightWing: 700), 0, "zero wing -> no notch")

let notched = NotchMetrics(screenFrame: screen, notchWidth: 210, notchHeight: 24)
let compact = NotchGeometry.compactFrame(for: notched)
expectEqual(compact.width, 210 + NotchGeometry.compactWingWidth * 2, "compact width = notch + two wings")
expectEqual(compact.height, 24, "compact height = menu bar")
expectEqual(compact.minY, 1117 - 24, "compact hugs the top edge")
expectEqual(compact.midX, screen.midX, "compact is centred")

let bare = NotchMetrics(screenFrame: screen, notchWidth: 0, notchHeight: 24)
let pill = NotchGeometry.compactFrame(for: bare)
expectEqual(pill.width, NotchGeometry.simulatedPillWidth, "no-notch pill keeps a fixed width")
expectEqual(pill.maxY, screen.maxY, "simulated island touches the top edge")
let bareExpanded = NotchGeometry.expandedFrame(for: bare)
expectEqual(bareExpanded.maxY, screen.maxY, "simulated expanded island stays attached to the top edge")
expectEqual(NotchGeometry.expandedContentHeight(hasQuota: false, hasReset: false, hasContext: true), 160, "missing quota reduces expanded height")
expectEqual(NotchGeometry.expandedContentHeight(hasQuota: true, hasReset: true, hasContext: true), 196, "quota and reset fit in the expanded height")
expectEqual(NotchGeometry.expandedContentHeight(hasQuota: false, hasReset: false, hasContext: false), 135, "missing metrics do not leave an empty panel")

let expanded = NotchGeometry.expandedFrame(for: notched)
expectEqual(expanded.width, NotchGeometry.expandedWidth, "expanded width")
expectEqual(expanded.height, NotchGeometry.expandedHeight, "expanded height")
expectEqual(expanded.minY, 1117 - NotchGeometry.expandedHeight, "expanded is top anchored")
expectEqual(expanded.midX, screen.midX, "expanded stays centred")

let narrowScreen = CGRect(x: 0, y: 0, width: 500, height: 800)
let narrow = NotchMetrics(screenFrame: narrowScreen, notchWidth: 150, notchHeight: 24)
let clamped = NotchGeometry.expandedFrame(for: narrow)
expect(clamped.minX >= narrowScreen.minX + 8, "expanded stays inside the display")
expect(clamped.maxX <= narrowScreen.maxX - 8, "expanded stays inside the display (right)")

// MARK: - Formatting

section("formatting")
expectEqual(IslandTheme.resolve(nil, dark: true), .obsidian, "default follows dark system appearance")
expectEqual(IslandTheme.resolve(nil, dark: false), .moonlight, "default follows light system appearance")
expectEqual(IslandTheme.resolve("system", dark: false), .moonlight, "system theme uses light appearance")
expectEqual(IslandTheme.resolve("deepSea", dark: false), .deepSea, "explicit theme is stable across system appearance")
expectEqual(IslandTheme.resolve("unknown", dark: true), .obsidian, "unknown saved theme falls back safely")
expectEqual(IslandFormatter.tokens(0), "0", "tokens 0")
expectEqual(IslandFormatter.tokens(999), "999", "tokens < 1k")
expectEqual(IslandFormatter.tokens(12_345), "12.3k", "tokens 12.3k")
expectEqual(IslandFormatter.tokens(128_400), "128k", "tokens stay short above 100k")
expectEqual(IslandFormatter.tokens(2_500_000), "2.5M", "tokens 2.5M")
expectEqual(IslandFormatter.percent(38.4), "38%", "percent rounds")
expectEqual(IslandFormatter.percent(99.6), "100%", "percent caps at 100")
expectEqual(IslandFormatter.duration(45), "45s", "duration seconds")
expectEqual(IslandFormatter.duration(90), "1m", "duration minutes")
expectEqual(IslandFormatter.duration(3_661), "1h 1m", "duration hours")
expectEqual(Copy.duration(90_000, chinese: false), "1d 1h", "English duration includes days")
expectEqual(Copy.duration(90_000, chinese: true), "1天 1小时", "Chinese duration includes days")
expectEqual(Copy.duration(45, chinese: true), "45秒", "Chinese duration uses localized seconds")

let now = Date(timeIntervalSince1970: 1_763_000_000)
expectEqual(IslandFormatter.countdown(to: now.addingTimeInterval(3_600), now: now), "1h", "countdown hours")
expectEqual(IslandFormatter.countdown(to: now.addingTimeInterval(-5), now: now), "now", "countdown past")

let quota = QuotaSnapshot(usedPercent: 65, windowMinutes: 10_080, resetsAt: nil, planType: nil)
expectEqual(IslandSnapshot(quota: quota).quotaPercent, 35, "compact quota reports remaining, not used")
expectEqual(quota.risk, .normal, "quota below 70 percent used is normal")
expectEqual(QuotaSnapshot(usedPercent: 70, windowMinutes: 300, resetsAt: nil, planType: nil).risk, .warning, "quota warning starts at 70 percent used")
expectEqual(QuotaSnapshot(usedPercent: 90, windowMinutes: 300, resetsAt: nil, planType: nil).risk, .critical, "quota critical starts at 90 percent used")

// MARK: - Rollout parsing

section("rollout parsing")

/// Shape copied from a real `token_count` event (values replaced).
let tokenLine = """
{"timestamp":"2026-11-17T11:00:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":50,"output_tokens":20,"total_tokens":123456},"last_token_usage":{"input_tokens":42000,"output_tokens":900,"total_tokens":42900},"model_context_window":258400},"rate_limits":{"limit_id":"codex","plan_type":"plus","primary":{"used_percent":38.5,"window_minutes":300,"resets_at":1763003600},"secondary":null,"credits":{"has_credits":true,"unlimited":false,"balance":"0"}}}}
"""

if case let .tokens(token)? = RolloutParser.parse(line: tokenLine) {
    expectEqual(token.totalTokens, 123_456, "total tokens")
    expectEqual(token.contextUsedTokens, 42_000, "context used = last input tokens")
    expectEqual(token.contextWindowTokens, 258_400, "context window")
    expectEqual(token.quota?.usedPercent, 38.5, "quota used percent")
    expectEqual(token.quota?.windowMinutes, 300, "quota window")
    expectEqual(token.quota?.planType, "plus", "plan type")
    expect(token.quota?.resetsAt != nil, "quota reset instant")
} else {
    expect(false, "token_count parses")
}

let started = RolloutParser.parse(line: #"{"payload":{"type":"task_started","turn_id":"turn-1","started_at":1763000000}}"#)
if case let .taskStarted(turnID, startedAt)? = started {
    expectEqual(turnID, "turn-1", "task_started turn id")
    expectEqual(startedAt?.timeIntervalSince1970, 1_763_000_000, "task_started instant")
} else {
    expect(false, "task_started parses")
}

let completed = RolloutParser.parse(line: #"{"payload":{"type":"task_complete","turn_id":"turn-1","duration_ms":4200}}"#)
if case let .taskCompleted(turnID, duration)? = completed {
    expectEqual(turnID, "turn-1", "task_complete turn id")
    expectEqual(duration, 4_200, "task_complete duration")
} else {
    expect(false, "task_complete parses")
}

if case let .context(cwd)? = RolloutParser.parse(line: #"{"payload":{"type":"thread_settings_applied","thread_settings":{"cwd":"/Users/me/code/codex-notch"}}}"#) {
    expectEqual(cwd, "/Users/me/code/codex-notch", "cwd nested in thread settings")
} else {
    expect(false, "thread_settings_applied cwd parses")
}

if case let .context(cwd)? = RolloutParser.parse(line: #"{"payload":{"type":"turn_context","cwd":"/Users/me/code/codex-notch"}}"#) {
    expectEqual(cwd, "/Users/me/code/codex-notch", "turn_context cwd")
} else {
    expect(false, "turn_context parses")
}

expectEqual(RolloutParser.parse(line: #"{"payload":{"type":"reasoning","text":"x"}}"#), nil, "unknown event ignored")
expectEqual(RolloutParser.parse(line: "not json"), nil, "garbage line ignored")
expectEqual(RolloutParser.parse(line: #"{"payload":{"type":"token_count"}}"#), nil, "token_count without info ignored")
let missingContext = #"{"payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":50},"model_context_window":258400}}}"#
if case let .tokens(token)? = RolloutParser.parse(line: missingContext) {
    expectEqual(token.contextWindowTokens, 0, "missing input usage does not invent a full context")
} else {
    expect(false, "token count with missing context parses")
}

// MARK: - Hook payloads

section("hook payloads")
if let event = HookParser.parse(line: #"{"type":"agent-turn-complete","thread-id":"th-1","turn-id":"tu-1","cwd":"/Users/me/proj"}"#) {
    expectEqual(event.kind, .turnCompleted, "agent-turn-complete kind")
    expectEqual(event.threadID, "th-1", "dashed thread id")
    expectEqual(event.turnID, "tu-1", "dashed turn id")
    expectEqual(event.cwd, "/Users/me/proj", "cwd")
} else {
    expect(false, "agent-turn-complete parses")
}

if let event = HookParser.parse(line: #"{"type":"turn_started","turn_id":"tu-2"}"#) {
    expectEqual(event.kind, .turnStarted, "snake_case variant")
    expectEqual(event.turnID, "tu-2", "snake turn id")
} else {
    expect(false, "snake_case hook parses")
}

if let event = HookParser.parse(line: #"{"type":"approval-requested"}"#) {
    expectEqual(event.kind, .waiting, "approval-requested maps to waiting")
} else {
    expect(false, "approval-requested parses")
}

expectEqual(HookParser.parse(line: #"{"type":"something-new"}"#), nil, "unknown hook type ignored")
expectEqual(HookParser.parse(line: ""), nil, "empty line ignored")

// MARK: - Session locator

section("session locator")
let fileManager = FileManager.default
let root = fileManager.temporaryDirectory.appendingPathComponent("codex-notch-tests-\(UUID().uuidString)", isDirectory: true)
defer { try? fileManager.removeItem(at: root) }

func writeFixture(_ relative: String, modified: Date) {
    let url = root.appendingPathComponent(relative)
    try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    fileManager.createFile(atPath: url.path, contents: Data("{}\n".utf8))
    try? fileManager.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
}

writeFixture("2026/11/16/rollout-old.jsonl", modified: now.addingTimeInterval(-3_600))
writeFixture("2026/11/17/rollout-new.jsonl", modified: now)
writeFixture("2026/11/17/notes.jsonl", modified: now.addingTimeInterval(60))

let newest = SessionLocator.newestRollout(in: root)
expectEqual(newest?.lastPathComponent, "rollout-new.jsonl", "picks the newest rollout, not other jsonl")
expectEqual(SessionLocator.dayFolder(of: newest!), "2026-11-17", "day folder from path")
expectEqual(SessionLocator.newestRollout(in: root.appendingPathComponent("missing")), nil, "missing root -> nil")

// MARK: - Real rollout bootstrap and hook boundary

section("session bootstrap")
var lineBuffer = JSONLBuffer(maxLineBytes: 12)
let splitUTF8 = Data("项目\n".utf8)
expect(lineBuffer.append(splitUTF8.prefix(2)).isEmpty, "partial UTF-8 is buffered")
expectEqual(lineBuffer.append(splitUTF8.dropFirst(2)).first.flatMap { String(data: $0, encoding: .utf8) }, "项目", "split UTF-8 stays intact")
expect(lineBuffer.append(Data(String(repeating: "x", count: 13).utf8)).isEmpty, "oversized partial line is not delivered")
expectEqual(lineBuffer.append(Data("continued\nok\n".utf8)).compactMap { String(data: $0, encoding: .utf8) }, ["ok"], "reader recovers after an oversized line")
let bootstrapFile = root.appendingPathComponent("bootstrap.jsonl")
let projectLine = #"{"type":"session_meta","payload":{"cwd":"/tmp/example-project"}}"#
let startLine = #"{"type":"event_msg","payload":{"type":"task_started","started_at":1763000000}}"#
let paddingLine = "{\"type\":\"response_item\",\"payload\":{\"text\":\"" + String(repeating: "x", count: 180_000) + "\"}}"
let partialLine = #"{"type":"event_msg","payload":{"type":"token_count""#
let completeLines = [projectLine, startLine, paddingLine, tokenLine].joined(separator: "\n") + "\n"
try! (completeLines + partialLine).write(to: bootstrapFile, atomically: true, encoding: .utf8)
if let restored = try? RolloutBootstrap.read(file: bootstrapFile) {
    expectEqual(restored.offset, UInt64(completeLines.utf8.count), "incomplete final line is reread after the next append")
    expect(restored.signals.contains(.context(cwd: "/tmp/example-project")), "restores project from real session_meta shape")
    expect(restored.signals.contains(.taskStarted(turnID: nil, startedAt: Date(timeIntervalSince1970: 1_763_000_000))), "restores start earlier than the last 64 KB")
    if case let .tokens(value)? = restored.signals.first(where: { if case .tokens = $0 { return true }; return false }) {
        expectEqual(value.totalTokens, 123_456, "restores latest actual token count")
        expectEqual(value.quota?.remainingPercent, 61.5, "restores remaining actual quota")
    } else {
        expect(false, "bootstrap restores token usage")
    }
} else {
    expect(false, "bootstrap reads rollout")
}

let boundaryFile = root.appendingPathComponent("bootstrap-boundary.jsonl")
let tokenBytes = Data((tokenLine + "\n").utf8)
var boundaryData = Data("x\n".utf8)
boundaryData.append(tokenBytes)
boundaryData.append(Data(repeating: 120, count: 4 * 1024 * 1024 - tokenBytes.count - 1))
boundaryData.append(10)
try! boundaryData.write(to: boundaryFile)
let boundarySignals = (try? RolloutBootstrap.read(file: boundaryFile))?.signals ?? []
expect(boundarySignals.contains { if case .tokens = $0 { return true }; return false }, "retains a complete record at the exact tail boundary")

let oldCompletion = #"{"timestamp":"2020-01-01T00:00:00.000Z","type":"event_msg","payload":{"type":"task_complete"}}"#
try! (completeLines + oldCompletion + "\n").write(to: bootstrapFile, atomically: true, encoding: .utf8)
expectEqual((try? RolloutBootstrap.read(file: bootstrapFile))?.signals.last, .turnAborted, "old completed turn is not shown as newly completed")
try! completeLines.write(to: bootstrapFile, atomically: true, encoding: .utf8)
try! fileManager.setAttributes([.modificationDate: Date().addingTimeInterval(-1_801)], ofItemAtPath: bootstrapFile.path)
expectEqual((try? RolloutBootstrap.read(file: bootstrapFile))?.signals.last, .turnAborted, "old running snapshot is not shown as live")

section("hook privacy")
let hook = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("codexnotch-hook")
let hookDir = root.appendingPathComponent("hook", isDirectory: true)
let process = Process()
process.executableURL = hook
process.environment = ProcessInfo.processInfo.environment.merging(["CODEX_NOTCH_HOME": hookDir.path]) { _, new in new }
process.arguments = [#"{"type":"agent-turn-complete","thread-id":"example","input-messages":["PRIVATE_PROMPT"],"last-assistant-message":"PRIVATE_RESPONSE","cwd":"/tmp/example-project"}"#]
try! process.run()
process.waitUntilExit()
let saved = (try? String(contentsOf: hookDir.appendingPathComponent("events.jsonl"), encoding: .utf8)) ?? ""
expectEqual(process.terminationStatus, 0, "hook succeeds")
expect(!saved.contains("PRIVATE_PROMPT") && !saved.contains("PRIVATE_RESPONSE"), "hook does not persist prompt or answer")
expectEqual(HookParser.parse(line: saved)?.kind, .turnCompleted, "sanitized hook still delivers completion")

// MARK: - Summary

print("")
if failures == 0 {
    print("\(checks) checks passed")
    exit(0)
} else {
    print("\(failures) of \(checks) checks failed")
    exit(1)
}
