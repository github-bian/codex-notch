// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CodexNotch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CodexNotch", targets: ["CodexNotch"]),
        .executable(name: "codexnotch-hook", targets: ["CodexNotchHook"]),
    ],
    targets: [
        .target(name: "CodexNotchCore"),
        .executableTarget(name: "CodexNotch", dependencies: ["CodexNotchCore"]),
        .executableTarget(name: "CodexNotchHook", dependencies: ["CodexNotchCore"]),
        // XCTest is not shipped with the Command Line Tools, so the test suite is a
        // plain executable that exits non-zero on the first failed assertion group.
        .executableTarget(name: "CodexNotchCoreTests", dependencies: ["CodexNotchCore"]),
    ]
)
