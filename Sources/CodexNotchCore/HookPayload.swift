import Foundation

/// A lifecycle event pushed by Codex through `notify = [...]` (or by any tool that
/// appends to the inbox). The island prefers these over file polling because they
/// arrive when the turn actually changes state.
public struct HookEvent: Equatable {
    public enum Kind: String, Equatable {
        case turnStarted
        case turnCompleted
        case waiting
        case failed
        case notice
    }

    public var kind: Kind
    public var threadID: String?
    public var turnID: String?
    public var cwd: String?
    public var message: String?
    /// The untouched JSON object, for forward compatibility and debugging.
    public var rawType: String

    public init(
        kind: Kind,
        threadID: String? = nil,
        turnID: String? = nil,
        cwd: String? = nil,
        message: String? = nil,
        rawType: String
    ) {
        self.kind = kind
        self.threadID = threadID
        self.turnID = turnID
        self.cwd = cwd
        self.message = message
        self.rawType = rawType
    }
}

public enum HookParser {
    /// Accepts both Codex's dashed payload (`thread-id`, `turn-id`) and our own
    /// snake/camel variants, so the hook helper can stay a dumb pipe.
    public static func parse(line: String) -> HookEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        return parse(data: data)
    }

    public static func parse(data: Data) -> HookEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        guard let root = object as? [String: Any] else { return nil }
        guard let rawType = string(root["type"]) ?? string(root["event"]) else { return nil }
        guard let kind = kind(for: rawType) else { return nil }

        return HookEvent(
            kind: kind,
            threadID: string(root["thread-id"]) ?? string(root["thread_id"]) ?? string(root["threadId"]),
            turnID: string(root["turn-id"]) ?? string(root["turn_id"]) ?? string(root["turnId"]),
            cwd: string(root["cwd"]),
            message: string(root["message"]) ?? string(root["last-assistant-message"]),
            rawType: rawType
        )
    }

    public static func kind(for rawType: String) -> HookEvent.Kind? {
        switch rawType {
        case "agent-turn-start", "turn-start", "turn_started", "task_started":
            return .turnStarted
        case "agent-turn-complete", "turn-complete", "turn_completed", "task_complete":
            return .turnCompleted
        case "approval-requested", "agent-approval-requested", "approval_requested":
            return .waiting
        case "agent-error", "error", "task_failed":
            return .failed
        case "notice", "agent-notice":
            return .notice
        default:
            return nil
        }
    }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty else { return nil }
        return value
    }
}
