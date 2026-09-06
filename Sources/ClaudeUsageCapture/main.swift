import Foundation

@main
struct ClaudeUsageCapture {
    static func main() {
        do {
            if CommandLine.arguments.contains("--install-statusline") {
                try installStatusLine()
                print("Claude Code usage capture enabled.")
                return
            }
            if CommandLine.arguments.contains("--remove-statusline") {
                try removeStatusLine()
                print("Claude Code usage capture removed.")
                return
            }

            let input = FileHandle.standardInput.readDataToEndOfFile()
            guard let payload = try? JSONDecoder().decode(StatusLinePayload.self, from: input) else {
                return
            }
            let capture = makeCapture(from: payload)
            guard !capture.windows.isEmpty else { return }
            try save(capture)
            print(statusText(for: capture))
        } catch {
            FileHandle.standardError.write(Data("Claude usage capture: \(error.localizedDescription)\n".utf8))
            Foundation.exit(1)
        }
    }

    private static func makeCapture(from payload: StatusLinePayload) -> ClaudeRateLimitCapture {
        let windows = [
            payload.rateLimits?.fiveHour.map { ClaudeRateLimitCapture.Window(id: "five-hour", name: "5 hours", usedPercent: Int($0.usedPercentage.rounded()), resetsAt: $0.resetsAt) },
            payload.rateLimits?.sevenDay.map { ClaudeRateLimitCapture.Window(id: "seven-day", name: "Weekly", usedPercent: Int($0.usedPercentage.rounded()), resetsAt: $0.resetsAt) }
        ].compactMap { $0 }
        return ClaudeRateLimitCapture(capturedAt: .now, windows: windows)
    }

    private static func save(_ capture: ClaudeRateLimitCapture) throws {
        let directory = try captureDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(capture).write(to: directory.appendingPathComponent("claude-rate-limits.json"), options: .atomic)
    }

    private static func statusText(for capture: ClaudeRateLimitCapture) -> String {
        let values = capture.windows.map { "\($0.name): \(max(0, 100 - $0.usedPercent))%" }
        return "Claude usage · " + values.joined(separator: " · ")
    }

    private static func installStatusLine() throws {
        let settingsURL = claudeSettingsURL()
        let configDirectory = settingsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)

        var settings: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            let data = try Data(contentsOf: settingsURL)
            guard let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CaptureError.invalidSettings
            }
            settings = decoded
        }
        guard settings["statusLine"] == nil else {
            throw CaptureError.existingStatusLine
        }

        settings["statusLine"] = [
            "type": "command",
            "command": NSHomeDirectory() + "/.local/bin/claude-usage-statusline",
            "refreshInterval": 60
        ]
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: settingsURL, options: .atomic)
    }

    private static func removeStatusLine() throws {
        let settingsURL = claudeSettingsURL()
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }
        let data = try Data(contentsOf: settingsURL)
        var settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let command = (settings["statusLine"] as? [String: Any])?["command"] as? String
        guard command == NSHomeDirectory() + "/.local/bin/claude-usage-statusline" else { return }
        settings.removeValue(forKey: "statusLine")
        let updated = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try updated.write(to: settingsURL, options: .atomic)
    }

    private static func claudeSettingsURL() -> URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] ?? NSHomeDirectory() + "/.claude", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    private static func captureDirectory() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CaptureError.applicationSupportUnavailable
        }
        return applicationSupport.appendingPathComponent("CodexUsageMenu", isDirectory: true)
    }
}

private struct StatusLinePayload: Decodable {
    struct RateLimits: Decodable {
        struct Window: Decodable {
            let usedPercentage: Double
            let resetsAt: Int?

            enum CodingKeys: String, CodingKey {
                case usedPercentage = "used_percentage"
                case resetsAt = "resets_at"
            }
        }

        let fiveHour: Window?
        let sevenDay: Window?

        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }
    }

    let rateLimits: RateLimits?

    enum CodingKeys: String, CodingKey {
        case rateLimits = "rate_limits"
    }
}

private struct ClaudeRateLimitCapture: Encodable {
    struct Window: Encodable {
        let id: String
        let name: String
        let usedPercent: Int
        let resetsAt: Int?
    }

    let capturedAt: Date
    let windows: [Window]
}

private enum CaptureError: LocalizedError {
    case existingStatusLine
    case invalidSettings
    case applicationSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .existingStatusLine:
            return "Claude Code already has a statusLine configuration. It was not changed."
        case .invalidSettings:
            return "Claude Code settings.json must contain a JSON object."
        case .applicationSupportUnavailable:
            return "Application Support is unavailable."
        }
    }
}
