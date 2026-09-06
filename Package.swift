// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentUsageMenu",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AgentUsageMenu", targets: ["CodexUsageMenu"]),
        .executable(name: "ClaudeUsageCapture", targets: ["ClaudeUsageCapture"])
    ],
    targets: [
        .executableTarget(name: "CodexUsageMenu"),
        .executableTarget(name: "ClaudeUsageCapture"),
        .testTarget(name: "CodexUsageMenuTests", dependencies: ["CodexUsageMenu"])
    ]
)
