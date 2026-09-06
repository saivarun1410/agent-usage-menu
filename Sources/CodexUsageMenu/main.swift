import AppKit
import Foundation
import SwiftUI

@main
struct CodexUsageMenuApp: App {
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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let snapshot = monitor.snapshot {
                snapshotContent(snapshot)
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
        .frame(width: 344, alignment: .leading)
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("Codex Usage")
                .font(.system(size: 15, weight: .semibold))
            if let plan = monitor.snapshot?.planType {
                Text(plan.capitalized + " plan")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func snapshotContent(_ snapshot: UsageSnapshot) -> some View {
        VStack(spacing: 0) {
            ForEach(snapshot.windows) { window in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(window.name)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(window.remainingPercent)% left")
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                    }
                    if let resetText = window.resetText {
                        Text(resetText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)

                if window.id != snapshot.windows.last?.id {
                    Divider()
                }
            }

            if snapshot.availableResetCredits > 0 {
                Divider()
                Text("\(snapshot.availableResetCredits) reset credit available")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }

            Divider()
            Text("Updated \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
            Text("Automatically refreshes every minute")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 10)
        }
        .padding(.horizontal, 14)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Button("Refresh now") { monitor.refresh() }
                .disabled(monitor.isRefreshing)
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            Divider()
            Button("Quit Codex Usage Menu") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
        }
    }
}

@MainActor
final class UsageMonitor: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
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
        guard let leastRemaining = snapshot?.windows.map(\.remainingPercent).min() else {
            return errorMessage == nil ? "Codex …" : "Codex —"
        }
        return "Codex \(leastRemaining)%"
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            do {
                let response = try await client.readRateLimits()
                snapshot = UsageSnapshot(response: response, updatedAt: .now)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
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
