import Foundation

public enum AgentPhase: String, Codable, Equatable, CaseIterable {
    case idle
    case running
    case waiting
    case done
    case error
}

public struct QuotaSnapshot: Equatable {
    /// 0...100, the share of the primary rate-limit window already consumed.
    public var usedPercent: Double
    public var windowMinutes: Int
    public var resetsAt: Date?
    public var planType: String?

    public init(usedPercent: Double, windowMinutes: Int, resetsAt: Date?, planType: String?) {
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
        self.planType = planType
    }

    public var remainingPercent: Double {
        min(100, max(0, 100 - usedPercent))
    }

    public var risk: QuotaRisk {
        if usedPercent >= 90 { return .critical }
        if usedPercent >= 70 { return .warning }
        return .normal
    }
}

public enum QuotaRisk { case normal, warning, critical }

/// The single value the island renders. Everything else is a side effect.
public struct IslandSnapshot: Equatable {
    public var phase: AgentPhase
    public var title: String?
    public var projectName: String?
    public var startedAt: Date?
    public var lastActivityAt: Date?
    public var totalTokens: Int
    public var contextUsedTokens: Int
    public var contextWindowTokens: Int
    public var quota: QuotaSnapshot?
    public var note: String?

    public init(
        phase: AgentPhase = .idle,
        title: String? = nil,
        projectName: String? = nil,
        startedAt: Date? = nil,
        lastActivityAt: Date? = nil,
        totalTokens: Int = 0,
        contextUsedTokens: Int = 0,
        contextWindowTokens: Int = 0,
        quota: QuotaSnapshot? = nil,
        note: String? = nil
    ) {
        self.phase = phase
        self.title = title
        self.projectName = projectName
        self.startedAt = startedAt
        self.lastActivityAt = lastActivityAt
        self.totalTokens = totalTokens
        self.contextUsedTokens = contextUsedTokens
        self.contextWindowTokens = contextWindowTokens
        self.quota = quota
        self.note = note
    }

    public static let idle = IslandSnapshot()

    public var contextPercent: Double? {
        guard contextWindowTokens > 0 else { return nil }
        return min(1, max(0, Double(contextUsedTokens) / Double(contextWindowTokens)))
    }

    public var isIdle: Bool { phase == .idle }

    /// Used by the collapsed wings; `nil` when Codex has not reported a limit yet.
    public var quotaPercent: Double? { quota?.remainingPercent }

    /// One short line for the wings, never the prompt itself.
    public var displayTitle: String {
        if let title, !title.isEmpty { return title }
        if let projectName, !projectName.isEmpty { return projectName }
        switch phase {
        case .running: return "Working"
        case .waiting: return "Waiting"
        case .done: return "Done"
        case .error: return "Failed"
        case .idle: return ""
        }
    }
}

public enum IslandFormatter {
    public static func tokens(_ value: Int) -> String {
        if value <= 0 { return "0" }
        if value < 1_000 { return "\(value)" }
        if value < 1_000_000 {
            let k = Double(value) / 1_000
            // One decimal while it is still a precise number, none once it is noise.
            return k < 100 ? String(format: "%.1fk", k) : String(format: "%.0fk", k)
        }
        return String(format: "%.1fM", Double(value) / 1_000_000)
    }

    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    public static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0s" }
        let total = Int(seconds)
        if total < 60 { return "\(total)s" }
        if total < 3_600 { return "\(total / 60)m" }
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    /// `resets_at` is an absolute instant, so the label stays correct across sleep.
    public static func countdown(to date: Date, now: Date = Date()) -> String {
        let remaining = date.timeIntervalSince(now)
        guard remaining > 0 else { return "now" }
        return duration(remaining)
    }
}
