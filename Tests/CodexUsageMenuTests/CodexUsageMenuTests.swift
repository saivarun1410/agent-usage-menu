import Foundation
import Testing
@testable import CodexUsageMenu

@Test func snapshotUsesRemainingUsageAndWindowLabels() throws {
    let response = GetAccountRateLimitsResponse(
        rateLimits: RateLimitSnapshot(limitId: "codex", limitName: nil, primary: RateLimitWindow(usedPercent: 16, resetsAt: 1_789_224_793, windowDurationMins: 10_080), secondary: nil, planType: "plus"),
        rateLimitsByLimitId: nil,
        rateLimitResetCredits: RateLimitResetCredits(availableCount: 1)
    )

    let snapshot = UsageSnapshot(response: response, updatedAt: .now)

    #expect(snapshot.planType == "plus")
    #expect(snapshot.availableResetCredits == 1)
    #expect(snapshot.windows.count == 1)
    #expect(snapshot.windows[0].name == "Codex · Weekly")
    #expect(snapshot.windows[0].remainingPercent == 84)
}
