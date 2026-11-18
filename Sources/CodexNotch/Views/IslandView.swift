import SwiftUI
import CodexNotchCore

struct IslandView: View {
    @ObservedObject var model: IslandViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            if model.expanded || !model.snapshot.isIdle {
                IslandBackground(metrics: model.metrics, expanded: model.expanded)
                    .transition(.opacity)
            }
            if model.expanded {
                ExpandedView(model: model).transition(.opacity)
            } else if !model.snapshot.isIdle {
                CompactView(model: model).transition(.opacity)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.32), value: model.expanded)
        .animation(.easeOut(duration: 0.18), value: model.snapshot.phase)
    }
}

struct CompactView: View {
    @ObservedObject var model: IslandViewModel

    private var snapshot: IslandSnapshot { model.snapshot }
    private var title: String {
        if snapshot.phase != .running { return Copy.phase(snapshot.phase) }
        return snapshot.title ?? snapshot.projectName ?? Copy.phase(snapshot.phase)
    }

    var body: some View {
        Group {
            if model.metrics.hasHardwareNotch {
                HStack(spacing: 0) {
                    leading.frame(width: NotchGeometry.compactWingWidth, alignment: .leading)
                    Color.clear.frame(width: model.metrics.notchWidth)
                    trailing.frame(width: NotchGeometry.compactWingWidth, alignment: .trailing)
                }
                .padding(.horizontal, 0)
            } else {
                HStack(spacing: 8) {
                    leading
                    Spacer(minLength: 4)
                    trailing
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { model.togglePinned() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Copy.phase(snapshot.phase)), \(title)"))
        .accessibilityValue(Text(accessibilityQuota))
        .accessibilityHint(Text(Copy.text("Click to pin the panel open", "点击钉住展开面板")))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.togglePinned() }
    }

    private var accessibilityQuota: String {
        guard let percent = snapshot.quotaPercent else { return "" }
        return Copy.text("\(IslandFormatter.percent(percent)) remaining", "剩余 \(IslandFormatter.percent(percent))")
    }

    private var leading: some View {
        HStack(spacing: 5) {
            PhaseDot(phase: snapshot.phase)
            if model.isDemo {
                Text("DEMO").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.55))
            }
            Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1).truncationMode(.tail)
        }
        .foregroundStyle(.white.opacity(0.94))
        .padding(.leading, 10)
    }

    private var trailing: some View {
        HStack(spacing: 5) {
            if let quota = snapshot.quota {
                Text(IslandFormatter.percent(quota.remainingPercent))
                    .foregroundStyle(quotaColor(quota))
            }
            if snapshot.totalTokens > 0 {
                Text(IslandFormatter.tokens(snapshot.totalTokens)).foregroundStyle(.white.opacity(0.6))
            }
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.trailing, 10)
    }
}

struct ExpandedView: View {
    @ObservedObject var model: IslandViewModel
    private var snapshot: IslandSnapshot { model.snapshot }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            content(now: timeline.date)
        }
    }

    private func content(now: Date) -> some View {
        VStack(spacing: 4) {
            topBar
            VStack(alignment: .leading, spacing: 8) {
                header(now: now)
                Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                if let quota = snapshot.quota {
                    quotaRow(quota, now: now)
                }
                if let context = snapshot.contextPercent {
                    contextRow(context)
                }
                HStack {
                    Text(Copy.text("Session total", "会话累计"))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    if snapshot.totalTokens > 0 {
                        Text("\(IslandFormatter.tokens(snapshot.totalTokens)) tokens")
                            .fontWeight(.medium).monospacedDigit()
                    } else {
                        Text("—").foregroundStyle(.white.opacity(0.45))
                    }
                }
                .font(.system(size: 10))
                .accessibilityElement(children: .combine)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 18)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.top, 3)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var topBar: some View {
        HStack {
            Text(model.isDemo ? "CODEX · DEMO" : "CODEX")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            Spacer(minLength: model.metrics.hasHardwareNotch ? model.metrics.notchWidth : 0)
            Button(action: { model.dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 23, height: 23)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(Copy.text("Close", "关闭")))
        }
        .padding(.horizontal, 20)
        .frame(height: max(24, model.metrics.hasHardwareNotch ? model.metrics.notchHeight : 24))
    }

    private func header(now: Date) -> some View {
        HStack(alignment: .center, spacing: 8) {
            PhaseDot(phase: snapshot.phase)
            VStack(alignment: .leading, spacing: 3) {
                Text(Copy.phase(snapshot.phase))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let title = snapshot.title ?? snapshot.projectName, !title.isEmpty {
                        Text(title).lineLimit(1).truncationMode(.tail)
                    }
                    if let startedAt = snapshot.startedAt, snapshot.phase == .running || snapshot.phase == .waiting {
                        if snapshot.title != nil || snapshot.projectName != nil { Text("·") }
                        Text(Copy.duration(now.timeIntervalSince(startedAt))).fixedSize()
                    }
                }
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.58))
            }
            Spacer(minLength: 2)
            Button(action: NotchController.openCodex) {
                Text(Copy.text("Open Codex", "打开 Codex"))
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(.white.opacity(snapshot.phase == .waiting ? 0.20 : 0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func quotaRow(_ quota: QuotaSnapshot, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(Copy.window(quota.windowMinutes)).foregroundStyle(.white.opacity(0.62))
                Spacer(minLength: 5)
                Text(Copy.text("\(IslandFormatter.percent(quota.remainingPercent)) remaining", "剩余 \(IslandFormatter.percent(quota.remainingPercent))"))
                    .fontWeight(.semibold).foregroundStyle(quotaColor(quota)).monospacedDigit()
            }
            meter(quota.usedPercent / 100, color: quotaColor(quota))
            if let reset = quota.resetsAt {
                Text(Copy.reset(reset, now: now)).font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
            }
        }
        .font(.system(size: 11))
        .accessibilityElement(children: .combine)
    }

    private func contextRow(_ context: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(Copy.text("Context", "上下文")).foregroundStyle(.white.opacity(0.62))
                Spacer(minLength: 5)
                Text("\(IslandFormatter.tokens(snapshot.contextUsedTokens)) / \(IslandFormatter.tokens(snapshot.contextWindowTokens))")
                    .monospacedDigit()
                Text(Copy.text("· \(IslandFormatter.percent((1 - context) * 100)) free", "· 剩余 \(IslandFormatter.percent((1 - context) * 100))"))
                    .foregroundStyle(.white.opacity(0.6)).monospacedDigit()
            }
            .lineLimit(1).minimumScaleFactor(0.85)
            meter(context, color: .white.opacity(0.75))
        }
        .font(.system(size: 11))
        .accessibilityElement(children: .combine)
    }

    private func meter(_ progress: Double, color: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule().fill(color).frame(width: proxy.size.width * min(1, max(0, progress)))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

struct IslandBackground: View {
    let metrics: NotchMetrics
    let expanded: Bool

    var body: some View {
        IslandShape(shoulder: expanded ? 14 : 5, bottomRadius: expanded ? 24 : 12)
            .fill(Color.black)
    }
}

/// The curved shoulders make the island flow into the screen's top edge.
struct IslandShape: Shape {
    var shoulder: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shoulder, bottomRadius) }
        set { shoulder = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let s = min(shoulder, rect.width / 4, rect.height / 2)
        let r = min(bottomRadius, (rect.width - 2 * s) / 2, (rect.height - s) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - s, y: rect.minY + s), control: CGPoint(x: rect.maxX - s, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - s, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - s - r, y: rect.maxY), control: CGPoint(x: rect.maxX - s, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + s + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + s, y: rect.maxY - r), control: CGPoint(x: rect.minX + s, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + s, y: rect.minY + s))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.minX + s, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct PhaseDot: View {
    let phase: AgentPhase

    var body: some View {
        Circle().fill(color).frame(width: 6, height: 6).accessibilityHidden(true)
    }

    private var color: Color {
        switch phase {
        case .running: return .orange
        case .waiting: return .cyan
        case .done: return .green
        case .error: return .red
        case .idle: return .gray
        }
    }
}

func quotaColor(_ quota: QuotaSnapshot) -> Color {
    switch quota.risk {
    case .normal: return .white
    case .warning: return .orange
    case .critical: return .red
    }
}
