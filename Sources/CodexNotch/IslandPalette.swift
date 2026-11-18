import SwiftUI
import CodexNotchCore

struct IslandPalette {
    let background: Color
    let card: Color
    let foreground: Color
    let secondary: Color
    let muted: Color
    let control: Color
    let track: Color
    let accent: Color
    let warning: Color
    let critical: Color

    static func palette(for theme: IslandTheme) -> IslandPalette {
        switch theme {
        case .moonlight:
            return IslandPalette(background: Color(red: 0.95, green: 0.95, blue: 0.96), card: Color.black.opacity(0.045), foreground: Color(white: 0.10), secondary: Color(white: 0.34), muted: Color(white: 0.42), control: Color.black.opacity(0.08), track: Color.black.opacity(0.12), accent: Color(red: 0.08, green: 0.38, blue: 0.78), warning: Color(red: 0.62, green: 0.31, blue: 0.01), critical: Color(red: 0.72, green: 0.11, blue: 0.12))
        case .deepSea:
            return IslandPalette(background: Color(red: 0.025, green: 0.045, blue: 0.075), card: Color(red: 0.08, green: 0.12, blue: 0.18), foreground: .white, secondary: Color.white.opacity(0.67), muted: Color.white.opacity(0.55), control: Color.white.opacity(0.12), track: Color.white.opacity(0.12), accent: Color(red: 0.43, green: 0.69, blue: 0.98), warning: .orange, critical: .red)
        case .amber:
            return IslandPalette(background: Color(red: 0.055, green: 0.041, blue: 0.032), card: Color(red: 0.13, green: 0.10, blue: 0.08), foreground: Color(red: 1, green: 0.96, blue: 0.90), secondary: Color(red: 0.78, green: 0.72, blue: 0.65), muted: Color(red: 0.69, green: 0.62, blue: 0.54), control: Color.white.opacity(0.12), track: Color.white.opacity(0.13), accent: Color(red: 0.94, green: 0.67, blue: 0.34), warning: .orange, critical: .red)
        case .obsidian, .system:
            return IslandPalette(background: .black, card: Color.white.opacity(0.055), foreground: .white, secondary: Color.white.opacity(0.67), muted: Color.white.opacity(0.55), control: Color.white.opacity(0.12), track: Color.white.opacity(0.10), accent: Color.white.opacity(0.85), warning: .orange, critical: .red)
        }
    }

    func quotaColor(_ quota: QuotaSnapshot) -> Color {
        switch quota.risk {
        case .normal: return accent
        case .warning: return warning
        case .critical: return critical
        }
    }
}
