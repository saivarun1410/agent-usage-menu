import AppKit
import Darwin
import Foundation
import SwiftUI

@main
struct AgentUsageMenuApp: App {
    @StateObject private var monitor = UsageMonitor()

    var body: some Scene {
        MenuBarExtra {
            UsageMenu(monitor: monitor)
        } label: {
            Text(monitor.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct UsageMenu: View {
    @ObservedObject var monitor: UsageMonitor
    @State private var selectedProvider: ProviderID = .codex

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if !providers.isEmpty {
                if providers.count > 1 {
                    providerTabs
                    Divider()
                }
                if let provider = displayedProvider {
                    providerContent(provider.presentation, showsProviderName: providers.count == 1)
                }
            } else if let error = monitor.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 16)
            } else {
                ProgressView("Loading usage…")
                    .font(.system(size: 12))
                    .padding(.vertical, 16)
            }

            Divider()
            footer
        }
        .frame(width: 380, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Agent Usage")
                .font(.system(size: 18, weight: .semibold))
            Text("Local rate-limit monitor")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }

    private var providerTabs: some View {
        Picker("Provider", selection: $selectedProvider) {
            ForEach(providers) { provider in
                Text(provider.id.label).tag(provider.id)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var providers: [Provider] {
        var available: [Provider] = []
        if let codex = monitor.codexSnapshot {
            available.append(Provider(id: .codex, presentation: codex.presentation))
        }
        if let claude = monitor.claudeSnapshot {
            available.append(Provider(id: .claude, presentation: claude.presentation))
        } else if monitor.isClaudeCodeInstalled {
            available.append(Provider(id: .claude, presentation: ClaudeUsageStore.waitingPresentation))
        }
        return available
    }

    private var displayedProvider: Provider? {
        providers.first(where: { $0.id == selectedProvider }) ?? providers.first
    }

    private func providerContent(_ provider: ProviderPresentation, showsProviderName: Bool) -> some View {
        VStack(spacing: 0) {
            if showsProviderName {
                HStack(alignment: .firstTextBaseline) {
                    Text(provider.name)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    if let detail = provider.detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 14)
            } else if let detail = provider.detail {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
            }

            if provider.windows.isEmpty {
                Text(provider.emptyMessage ?? "Usage is not available yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
            } else {
                ForEach(provider.windows) { window in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(window.name)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text("\(window.remainingPercent)% left")
                                .font(.system(size: 14, weight: .semibold))
                                .monospacedDigit()
                        }
                        if let resetText = window.resetText {
                            Text(resetText)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 15)

                    if window.id != provider.windows.last?.id {
                        Divider()
                    }
                }
            }

            if provider.availableResetCredits > 0 {
                Divider()
                Text("\(provider.availableResetCredits) reset credit available")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            }

            if let updatedLabel = provider.updatedLabel, let updatedAt = provider.updatedAt {
                Divider()
                Text(updatedLabel + " " + updatedAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
            }
            if let refreshLabel = provider.refreshLabel {
                Text(refreshLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, provider.updatedAt == nil ? 0 : 4)
                    .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, 18)
    }

    private enum ProviderID: String, Identifiable {
        case codex
        case claude

        var id: String { rawValue }

        var label: String {
            switch self {
            case .codex: "Codex"
            case .claude: "Claude Code"
            }
        }
    }

    private struct Provider: Identifiable {
        let id: ProviderID
        let presentation: ProviderPresentation
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Button("Refresh now") { monitor.refresh() }
                .disabled(monitor.isRefreshing)
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
            Divider()
            Button("Quit Agent Usage Menu") { quitLaunchAgent() }
                .buttonStyle(.plain)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
        }
    }

    private func quitLaunchAgent() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(getuid())/com.agentusagemenu.app"]
        try? process.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApplication.shared.terminate(nil)
        }
    }
}

@MainActor
final class UsageMonitor: ObservableObject {
    @Published private(set) var codexSnapshot: UsageSnapshot?
    @Published private(set) var claudeSnapshot: ClaudeUsageSnapshot?
    @Published private(set) var isClaudeCodeInstalled = ClaudeUsageStore.isClaudeCodeInstalled
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false

    private let client = CodexAppServerClient()
    private var refreshTimer: Timer?

    init() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    var menuBarTitle: String {
        let labels = [
            codexSnapshot?.windows.map(\.remainingPercent).min().map { "Codex \($0)%" },
            claudeSnapshot?.windows.map(\.remainingPercent).min().map { "Claude \($0)%" }
        ].compactMap { $0 }
        guard !labels.isEmpty else {
            return errorMessage == nil ? "Agents …" : "Agents —"
        }
        return labels.joined(separator: " | ")
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        claudeSnapshot = ClaudeUsageStore.load()
        isClaudeCodeInstalled = ClaudeUsageStore.isClaudeCodeInstalled

        Task {
            do {
                let response = try await client.readRateLimits()
                codexSnapshot = UsageSnapshot(response: response, updatedAt: .now)
                errorMessage = nil
            } catch {
                if claudeSnapshot == nil {
                    errorMessage = error.localizedDescription
                }
            }
            isRefreshing = false
        }
    }
}

struct UsageSnapshot: Sendable {
    struct Window: Identifiable, Sendable {
        let id: String
        let name: String
        let remainingPercent: Int
        let resetAt: Date?

        var resetText: String? {
            guard let resetAt else { return nil }
            return "Resets " + resetAt.formatted(date: .abbreviated, time: .shortened)
        }
    }

    let planType: String?
    let windows: [Window]
    let availableResetCredits: Int
    let updatedAt: Date

    var presentation: ProviderPresentation {
        ProviderPresentation(
            name: "Codex",
            detail: planType.map { $0.capitalized + " plan" },
            windows: windows,
            availableResetCredits: availableResetCredits,
            updatedAt: updatedAt,
            updatedLabel: "Updated",
            refreshLabel: "Automatically refreshes every minute",
            emptyMessage: nil
        )
    }

    init(response: GetAccountRateLimitsResponse, updatedAt: Date) {
        let limits = response.rateLimitsByLimitId ?? [response.rateLimits.limitId ?? "codex": response.rateLimits]
        self.planType = response.rateLimits.planType
        self.availableResetCredits = response.rateLimitResetCredits?.availableCount ?? 0
        self.updatedAt = updatedAt
        self.windows = limits
            .flatMap { key, limit in
                [
                    Self.makeWindow(limit.primary, name: Self.windowName(for: limit, fallback: key, position: "primary"), id: "\(key)-primary"),
                    Self.makeWindow(limit.secondary, name: Self.windowName(for: limit, fallback: key, position: "secondary"), id: "\(key)-secondary")
                ].compactMap { $0 }
            }
            .sorted { $0.remainingPercent < $1.remainingPercent }
    }

    private static func makeWindow(_ window: RateLimitWindow?, name: String, id: String) -> Window? {
        guard let window else { return nil }
        return Window(
            id: id,
            name: name,
            remainingPercent: max(0, 100 - window.usedPercent),
            resetAt: window.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }

    private static func windowName(for limit: RateLimitSnapshot, fallback: String, position: String) -> String {
        let bucketName = limit.limitName ?? (fallback == "codex" ? "Codex" : fallback)
        let window = position == "primary" ? limit.primary : limit.secondary
        guard let duration = window?.windowDurationMins else { return bucketName }

        let durationName: String
        switch duration {
        case 60: durationName = "1 hour"
        case 300: durationName = "5 hours"
        case 1440: durationName = "Daily"
        case 10080: durationName = "Weekly"
        default: durationName = "\(duration) min"
        }
        return "\(bucketName) · \(durationName)"
    }
}

struct ProviderPresentation: Sendable {
    let name: String
    let detail: String?
    let windows: [UsageSnapshot.Window]
    let availableResetCredits: Int
    let updatedAt: Date?
    let updatedLabel: String?
    let refreshLabel: String?
    let emptyMessage: String?
}

struct ClaudeUsageSnapshot: Sendable {
    let windows: [UsageSnapshot.Window]
    let capturedAt: Date

    var presentation: ProviderPresentation {
        ProviderPresentation(
            name: "Claude Code",
            detail: "Latest session",
            windows: windows,
            availableResetCredits: 0,
            updatedAt: capturedAt,
            updatedLabel: "Captured",
            refreshLabel: "Updates while Claude Code is active",
            emptyMessage: nil
        )
    }
}

struct ClaudeUsageStore {
    private static let fileName = "claude-rate-limits.json"

    static var isClaudeCodeInstalled: Bool {
        let candidates = [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            NSHomeDirectory() + "/.local/bin/claude"
        ]
        return candidates.contains { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static var waitingPresentation: ProviderPresentation {
        ProviderPresentation(
            name: "Claude Code",
            detail: "Waiting for session data",
            windows: [],
            availableResetCredits: 0,
            updatedAt: nil,
            updatedLabel: nil,
            refreshLabel: "The tab updates after Claude Code receives a response.",
            emptyMessage: "Claude Code is installed. Usage has not been captured yet."
        )
    }

    static func load() -> ClaudeUsageSnapshot? {
        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directories = ["AgentUsageMenu", "CodexUsageMenu"]
        guard let data = directories.lazy
            .map({ applicationSupport.appendingPathComponent($0, isDirectory: true).appendingPathComponent(fileName) })
            .compactMap({ try? Data(contentsOf: $0) })
            .first else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let capture = try? decoder.decode(ClaudeRateLimitCapture.self, from: data) else { return nil }

        let windows = capture.windows.map { window in
            UsageSnapshot.Window(
                id: "claude-\(window.id)",
                name: window.name,
                remainingPercent: max(0, 100 - window.usedPercent),
                resetAt: window.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            )
        }
        return windows.isEmpty ? nil : ClaudeUsageSnapshot(windows: windows, capturedAt: capture.capturedAt)
    }
}

struct ClaudeRateLimitCapture: Codable, Sendable {
    struct Window: Codable, Sendable {
        let id: String
        let name: String
        let usedPercent: Int
        let resetsAt: Int?
    }

    let capturedAt: Date
    let windows: [Window]
}

actor CodexAppServerClient {
    private let decoder = JSONDecoder()

    func readRateLimits() throws -> GetAccountRateLimitsResponse {
        guard let executable = Self.findCodexExecutable() else {
            throw UsageError.codexNotFound
        }

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        try process.run()
        defer {
            if process.isRunning { process.terminate() }
        }

        var buffer = Data()
        try write(request: [
            "id": 1,
            "method": "initialize",
            "params": ["clientInfo": ["name": "codex-usage-menu", "version": "1.0.0"]]
        ], to: input.fileHandleForWriting)
        _ = try readResult(for: 1, from: output.fileHandleForReading, buffer: &buffer)

        try write(request: ["id": 2, "method": "account/rateLimits/read"], to: input.fileHandleForWriting)
        let result = try readResult(for: 2, from: output.fileHandleForReading, buffer: &buffer)
        return try decoder.decode(GetAccountRateLimitsResponse.self, from: result)
    }

    private func write(request: [String: Any], to handle: FileHandle) throws {
        var data = try JSONSerialization.data(withJSONObject: request)
        data.append(0x0A)
        try handle.write(contentsOf: data)
    }

    private func readResult(for requestID: Int, from handle: FileHandle, buffer: inout Data) throws -> Data {
        while true {
            if let newline = buffer.firstRange(of: Data([0x0A])) {
                let line = buffer.subdata(in: 0..<newline.lowerBound)
                buffer.removeSubrange(0...newline.lowerBound)
                guard !line.isEmpty else { continue }
                let object = try JSONSerialization.jsonObject(with: line) as? [String: Any]
                guard let id = object?["id"] as? NSNumber, id.intValue == requestID else { continue }
                if let error = object?["error"] as? [String: Any], let message = error["message"] as? String {
                    throw UsageError.server(message)
                }
                guard let result = object?["result"] else {
                    throw UsageError.invalidResponse
                }
                return try JSONSerialization.data(withJSONObject: result)
            }

            let next = handle.availableData
            guard !next.isEmpty else { throw UsageError.serverExited }
            buffer.append(next)
        }
    }

    private static func findCodexExecutable() -> URL? {
        let fileManager = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            NSHomeDirectory() + "/.local/bin/codex"
        ]
        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }
}

enum UsageError: LocalizedError {
    case codexNotFound
    case server(String)
    case serverExited
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "Codex CLI was not found. Install it, sign in, then refresh."
        case .server(let message):
            return "Codex could not read usage: \(message)"
        case .serverExited:
            return "Codex app server ended before returning usage."
        case .invalidResponse:
            return "Codex returned an unrecognised usage response."
        }
    }
}

struct GetAccountRateLimitsResponse: Codable, Sendable {
    let rateLimits: RateLimitSnapshot
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?
    let rateLimitResetCredits: RateLimitResetCredits?
}

struct RateLimitSnapshot: Codable, Sendable {
    let limitId: String?
    let limitName: String?
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
    let planType: String?
}

struct RateLimitWindow: Codable, Sendable {
    let usedPercent: Int
    let resetsAt: Int?
    let windowDurationMins: Int?
}

struct RateLimitResetCredits: Codable, Sendable {
    let availableCount: Int
}
