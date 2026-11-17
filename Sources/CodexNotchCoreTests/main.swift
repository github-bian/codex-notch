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
expect(pill.maxY < screen.maxY - 24, "no-notch pill drops below the menu bar")

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

let now = Date(timeIntervalSince1970: 1_763_000_000)
expectEqual(IslandFormatter.countdown(to: now.addingTimeInterval(3_600), now: now), "1h", "countdown hours")
expectEqual(IslandFormatter.countdown(to: now.addingTimeInterval(-5), now: now), "now", "countdown past")

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

// MARK: - Summary

print("")
if failures == 0 {
    print("\(checks) checks passed")
    exit(0)
} else {
    print("\(failures) of \(checks) checks failed")
    exit(1)
}
