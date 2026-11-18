import Foundation

/// One place for the island and menu's English and Simplified Chinese copy.
public enum Copy {
    public static var isChinese: Bool {
        let language = (Locale.preferredLanguages.first ?? "en").lowercased()
        return language.hasPrefix("zh") && !language.contains("hant") && !language.contains("tw") && !language.contains("hk") && !language.contains("mo")
    }

    public static func text(_ english: String, _ chinese: String) -> String {
        isChinese ? chinese : english
    }

    public static func phase(_ phase: AgentPhase) -> String {
        switch phase {
        case .idle: return text("No active task", "暂无进行中的任务")
        case .running: return text("Running", "运行中")
        case .waiting: return text("Waiting for approval", "等待审批")
        case .done: return text("Completed", "已完成")
        case .error: return text("Failed", "已失败")
        }
    }

    public static func duration(_ seconds: TimeInterval, chinese: Bool = isChinese) -> String {
        guard seconds.isFinite else { return "0s" }
        let total = max(0, Int(seconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return chinese ? "\(days)天 \(hours)小时" : "\(days)d \(hours)h" }
        if hours > 0 { return chinese ? "\(hours)小时 \(minutes)分" : "\(hours)h \(minutes)m" }
        if minutes > 0 { return chinese ? "\(minutes)分" : "\(minutes)m" }
        return chinese ? "\(total)秒" : "\(total)s"
    }

    public static func window(_ minutes: Int) -> String {
        if minutes <= 0 { return text("Usage limit", "使用额度") }
        if minutes % 1_440 == 0 { return text("\(minutes / 1_440)-day limit", "\(minutes / 1_440) 天额度") }
        if minutes % 60 == 0 { return text("\(minutes / 60)-hour limit", "\(minutes / 60) 小时额度") }
        return text("\(minutes)-minute limit", "\(minutes) 分钟额度")
    }

    public static func reset(_ date: Date, now: Date) -> String {
        if date <= now { return text("Resets now", "现在重置") }
        let time = duration(date.timeIntervalSince(now))
        return text("Resets in \(time)", "\(time)后重置")
    }
}
