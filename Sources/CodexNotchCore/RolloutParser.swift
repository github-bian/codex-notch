import Foundation

/// Values read from a session's `token_count` event.
public struct TokenSnapshot: Equatable {
    public var totalTokens: Int
    public var contextUsedTokens: Int
    public var contextWindowTokens: Int
    public var quota: QuotaSnapshot?

    public init(totalTokens: Int, contextUsedTokens: Int, contextWindowTokens: Int, quota: QuotaSnapshot?) {
        self.totalTokens = totalTokens
        self.contextUsedTokens = contextUsedTokens
        self.contextWindowTokens = contextWindowTokens
        self.quota = quota
    }
}

/// A fact observed in a rollout file. The island reacts to signals, not to files.
public enum RolloutSignal: Equatable {
    case taskStarted(turnID: String?, startedAt: Date?)
    case tokens(TokenSnapshot)
    case taskCompleted(turnID: String?, durationMs: Int?)
    case turnAborted
    case context(cwd: String)
}

/// Parses one JSONL line from `~/.codex/sessions/**/rollout-*.jsonl`.
///
/// Deliberately tolerant: unknown event types return `nil` instead of failing, and
/// every numeric field is optional. Codex is free to add fields; the parser only
/// depends on the ones verified against a real rollout.
public enum RolloutParser {
    public static func parse(line: String) -> RolloutSignal? {
        guard let data = line.data(using: .utf8) else { return nil }
        return parse(data: data)
    }

    public static func parse(data: Data) -> RolloutSignal? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any],
              let payload = root["payload"] as? [String: Any],
              let type = payload["type"] as? String
        else { return nil }

        switch type {
        case "task_started":
            return .taskStarted(
                turnID: string(payload["turn_id"]) ?? string(payload["root_turn_id"]),
                startedAt: date(payload["started_at"])
            )
        case "task_complete":
            return .taskCompleted(
                turnID: string(payload["turn_id"]) ?? string(payload["root_turn_id"]),
                durationMs: int(payload["duration_ms"])
            )
        case "turn_aborted", "task_aborted":
            return .turnAborted
        case "token_count":
            return tokenSnapshot(from: payload).map(RolloutSignal.tokens)
        case "turn_context":
            if let cwd = string(payload["cwd"]) ?? string(payload["working_dir"]) {
                return .context(cwd: cwd)
            }
            return nil
        case "thread_settings_applied":
            // The working directory lives one level down in this event, not at the root.
            if let settings = payload["thread_settings"] as? [String: Any],
               let cwd = string(settings["cwd"]) {
                return .context(cwd: cwd)
            }
            return nil
        default:
            return nil
        }
    }

    public static func tokenSnapshot(from payload: [String: Any]) -> TokenSnapshot? {
        guard let info = payload["info"] as? [String: Any] else { return nil }
        let total = (info["total_token_usage"] as? [String: Any]).flatMap { int($0["total_tokens"]) }
        let last = info["last_token_usage"] as? [String: Any]
        // `input_tokens` already includes the cached share; never add them up.
        let contextUsed = last.flatMap { int($0["input_tokens"]) }
            ?? int(info["model_context_window"])
        let contextWindow = int(info["model_context_window"]) ?? 0

        guard let totalTokens = total, totalTokens >= 0 else { return nil }

        return TokenSnapshot(
            totalTokens: totalTokens,
            contextUsedTokens: max(0, contextUsed ?? 0),
            contextWindowTokens: max(0, contextWindow),
            quota: quota(from: payload["rate_limits"] as? [String: Any])
        )
    }

    public static func quota(from raw: [String: Any]?) -> QuotaSnapshot? {
        guard let raw, let primary = raw["primary"] as? [String: Any] else { return nil }
        guard let used = double(primary["used_percent"]) else { return nil }
        return QuotaSnapshot(
            usedPercent: min(100, max(0, used)),
            windowMinutes: int(primary["window_minutes"]) ?? 0,
            resetsAt: date(primary["resets_at"]),
            planType: string(raw["plan_type"])
        )
    }

    // MARK: - Tolerant scalar readers (JSONSerialization hands back NSNumber)

    static func string(_ value: Any?) -> String? {
        if let string = value as? String, !string.isEmpty { return string }
        return nil
    }

    static func int(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? String { return Int(value) }
        return nil
    }

    static func double(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value) }
        return nil
    }

    /// Epoch seconds. Guards against milliseconds or bogus values sneaking in.
    static func date(_ value: Any?) -> Date? {
        guard let raw = double(value) else { return nil }
        let seconds = raw > 10_000_000_000 ? raw / 1_000 : raw
        guard seconds > 1_600_000_000, seconds < 4_000_000_000 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}
