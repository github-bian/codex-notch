import Foundation

public enum IslandTheme: String, CaseIterable {
    case system, obsidian, moonlight, deepSea, amber

    public static let preferenceKey = "islandTheme"

    public static func resolve(_ storedValue: String?, dark: Bool) -> IslandTheme {
        guard let value = storedValue.flatMap(IslandTheme.init(rawValue:)) else {
            return dark ? .obsidian : .moonlight
        }
        return value == .system ? (dark ? .obsidian : .moonlight) : value
    }
}
