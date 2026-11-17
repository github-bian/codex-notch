import SwiftUI
import CodexNotchCore

struct IslandView: View {
    @ObservedObject var model: IslandViewModel

    var body: some View {
        ZStack(alignment: .top) {
            if model.expanded {
                ExpandedView(model: model)
                    .transition(.opacity)
            } else if !model.snapshot.isIdle {
                CompactView(model: model)
                    .transition(.opacity)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: model.expanded)
        .animation(.easeOut(duration: 0.18), value: model.snapshot.phase)
    }
}

// MARK: - Compact wings

struct CompactView: View {
    @ObservedObject var model: IslandViewModel

    var body: some View {
        let metrics = model.metrics
        Group {
            if metrics.hasHardwareNotch {
                HStack(spacing: 0) {
                    leading
                        .padding(.leading, 14)
                        .frame(width: NotchGeometry.compactWingWidth, alignment: .leading)
                    Color.clear
                        .frame(width: metrics.notchWidth)
                    trailing
                        .padding(.trailing, 14)
                        .frame(width: NotchGeometry.compactWingWidth, alignment: .trailing)
                }
            } else {
                HStack(spacing: 8) {
                    leading
                    Spacer(minLength: 6)
                    trailing
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IslandBackground(metrics: metrics, expanded: false))
        .contentShape(Rectangle())
        .onTapGesture { model.togglePinned() }
    }

    private var leading: some View {
        HStack(spacing: 6) {
            PhaseDot(phase: model.snapshot.phase)
            Text(model.snapshot.displayTitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        HStack(spacing: 6) {
            if let percent = model.snapshot.quotaPercent {
                Text(IslandFormatter.percent(percent))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(quotaColor(percent))
            }
            if model.snapshot.totalTokens > 0 {
                Text(IslandFormatter.tokens(model.snapshot.totalTokens))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Expanded card

struct ExpandedView: View {
    @ObservedObject var model: IslandViewModel

    private var snapshot: IslandSnapshot { model.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider().overlay(Color.white.opacity(0.08))
            if let quota = snapshot.quota {
                meterRow(
                    label: quotaLabel(quota),
                    value: "\(IslandFormatter.percent(quota.remainingPercent)) left",
                    progress: quota.usedPercent / 100,
                    tint: quotaColor(quota.usedPercent)
                )
            }
            if let context = snapshot.contextPercent {
                meterRow(
                    label: "Context",
                    value: "\(IslandFormatter.tokens(snapshot.contextUsedTokens)) / \(IslandFormatter.tokens(snapshot.contextWindowTokens))",
                    progress: context,
                    tint: .blue
                )
            }
            statsRow
            Spacer(minLength: 0)
            footer
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(IslandBackground(metrics: model.metrics, expanded: true))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            PhaseDot(phase: snapshot.phase)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.displayTitle.isEmpty ? "Codex" : snapshot.displayTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Button(action: NotchController.openCodex) {
                Text("Open")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            Button(action: { model.dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let project = snapshot.projectName { parts.append(project) }
        if let startedAt = snapshot.startedAt, snapshot.phase == .running {
            parts.append(IslandFormatter.duration(Date().timeIntervalSince(startedAt)))
        }
        if let note = snapshot.note, !note.isEmpty { parts.append(note) }
        if parts.isEmpty { parts.append("No active turn") }
        return parts.joined(separator: " · ")
    }

    private func meterRow(label: String, value: String, progress: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(value)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(3, proxy.size.width * min(1, max(0, progress))))
                }
            }
            .frame(height: 4)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 18) {
            stat("Tokens", IslandFormatter.tokens(snapshot.totalTokens))
            if let quota = snapshot.quota, let resetsAt = quota.resetsAt {
                stat("Resets in", IslandFormatter.countdown(to: resetsAt))
            }
            Spacer(minLength: 0)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "cursorarrow.rays")
                .font(.system(size: 9))
            Text("Hover to peek · click to pin")
                .font(.system(size: 9, weight: .regular, design: .rounded))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white.opacity(0.3))
    }

    private func quotaLabel(_ quota: QuotaSnapshot) -> String {
        let window: String
        switch quota.windowMinutes {
        case 0:
            window = "Quota"
        case let minutes where minutes % 1_440 == 0:
            window = "\(minutes / 1_440)d window"
        case let minutes where minutes % 60 == 0:
            window = "\(minutes / 60)h window"
        default:
            window = "\(quota.windowMinutes)m window"
        }
        if let plan = quota.planType, !plan.isEmpty {
            return "\(window) · \(plan)"
        }
        return window
    }
}

// MARK: - Shared bits

struct IslandBackground: View {
    let metrics: NotchMetrics
    let expanded: Bool

    var body: some View {
        if expanded {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        } else if metrics.hasHardwareNotch {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 14,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color.black)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }
}

struct PhaseDot: View {
    let phase: AgentPhase

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .overlay(
                Circle().stroke(color.opacity(0.35), lineWidth: 3)
                    .opacity(phase == .running ? 1 : 0)
            )
    }

    private var color: Color {
        switch phase {
        case .running: return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .waiting: return Color(red: 0.2, green: 0.84, blue: 0.78)
        case .done: return Color(red: 0.13, green: 0.77, blue: 0.37)
        case .error: return Color(red: 0.94, green: 0.27, blue: 0.27)
        case .idle: return Color.white.opacity(0.35)
        }
    }
}

func quotaColor(_ usedPercent: Double) -> Color {
    if usedPercent >= 90 { return Color(red: 0.94, green: 0.27, blue: 0.27) }
    if usedPercent >= 70 { return Color(red: 1.0, green: 0.62, blue: 0.04) }
    return Color(red: 0.13, green: 0.77, blue: 0.37)
}
