import Foundation
import XCTest
#if os(visionOS)
@testable import SeldonVision
#else
@testable import Seldon
#endif

final class UsageDecodingTests: XCTestCase {
    func testDecodesVerifiedFieldsAndOnlyTracksDiagnosticPresence() throws {
        let data = Data(#"""
        {
          "generated_at": "2026-09-20T20:42:00Z",
          "counts": { "cache": 0, "error": 1, "live": 1, "stale": 0 },
          "results": [
            {
              "account_id": "acct-internal",
              "status": "live",
              "sample": {
                "account_id": "acct-internal",
                "provider": "Claude",
                "label": "Claude personal",
                "plan": "Pro",
                "observed_at": "2026-09-20T20:40:00.125Z",
                "age_seconds": 120,
                "windows": [{
                  "id": "five-hour",
                  "name": "Five-hour window",
                  "used_percent": 42.6,
                  "resets_at": "2026-09-20T21:45:00Z",
                  "window_seconds": 18000
                }],
                "diagnostics": [{ "code": "provider_note", "message": "backend text is not display-safe" }],
                "raw": { "secret": "must not enter the model" }
              }
            },
            {
              "account_id": "acct-error",
              "status": "error",
              "sample": null,
              "error": { "message": "private backend diagnostic" }
            }
          ]
        }
        """#.utf8)

        let snapshot = try JSONDecoder().decode(UsageSnapshot.self, from: data)

        XCTAssertEqual(snapshot.results.count, 2)
        XCTAssertEqual(snapshot.counts.live, 1)
        XCTAssertEqual(snapshot.counts.error, 1)
        XCTAssertEqual(snapshot.results[0].sample?.label, "Claude personal")
        XCTAssertEqual(snapshot.results[0].sample?.windows[0].usedPercent, 42.6)
        XCTAssertTrue(snapshot.results[0].sample?.hasDiagnostics == true)
        XCTAssertTrue(snapshot.results[1].hasError)
        XCTAssertNil(snapshot.results[1].sample)
    }

    func testRejectsNonISO8601Timestamp() {
        XCTAssertThrowsError(try TimestampCodec.date(from: "not-a-date"))
    }

    func testConnectionURLRejectsUserinfo() {
        XCTAssertNil(ConnectionURL.parse("https://operator:secret@example.test:8080"))
        XCTAssertNotNil(ConnectionURL.parse("http://tunnel-host:8080"))
    }

    func testPastAgendaResetIsReported() {
        let now = Date(timeIntervalSince1970: 10_000)
        let past = Date(timeIntervalSince1970: 9_000)

        XCTAssertTrue(UsageFormatters.agendaResetText(for: past, now: now).hasPrefix("Reported "))
        XCTAssertTrue(UsageFormatters.agendaResetText(for: now + 1_000, now: now).hasPrefix("Resets "))
    }

    func testWindowDurationAppearsWhenNameDoesNotExplainIt() {
        XCTAssertFalse(UsageFormatters.shouldShowDuration(for: "Five-hour window"))
        XCTAssertTrue(UsageFormatters.shouldShowDuration(for: "Primary quota"))
        XCTAssertEqual(UsageFormatters.duration(18_000), "5 hours")
    }

    func testForecastDecodingKeepsSafePresenceFlagsAndPoolMembers() throws {
        let data = Data(#"""
        {
          "generated_at": "2026-09-20T20:42:00Z",
          "status": "incomplete",
          "accounts": [{
            "account_id": "acct-internal",
            "provider": "codex",
            "plan": "Pro",
            "generated_at": "2026-09-20T20:42:00Z",
            "status": "estimated_qualified",
            "account_status": "ready",
            "history_sample_count": 8,
            "coverage_hours": 24,
            "lookback_hours": 48,
            "latest_observed_at": "2026-09-20T20:40:00Z",
            "current_sample_age_seconds": 120,
            "exhaustion_at": "2026-09-21T04:42:00Z",
            "limiting_window_name": "Five-hour window",
            "qualification": "backend qualification text is not displayed",
            "history_error": "",
            "windows": [{
              "id": "five-hour",
              "name": "Five-hour window",
              "window_seconds": 18000,
              "used_percent": 42.6,
              "remaining_percent": 57.4,
              "resets_at": "2026-09-20T21:45:00Z",
              "status": "steady",
              "coverage_24h_hours": 24,
              "coverage_48h_hours": 24,
              "sample_count_48h": 8,
              "exhaustion_at": "2026-09-21T04:42:00Z",
              "diagnostics": [{ "code": "private", "message": "private backend detail" }]
            }],
            "diagnostics": [{ "code": "private_account", "message": "private account detail" }]
          }],
          "pools": [{
            "key": "codex:Pro:five-hour:18000",
            "provider": "codex",
            "plan": "Pro",
            "plan_known": true,
            "window_id": "five-hour",
            "window_name": "Five-hour window",
            "window_seconds": 18000,
            "compatibility": "same_capacity",
            "comparable": true,
            "members": [{
              "account_id": "acct-internal",
              "label": "Personal",
              "status": "steady",
              "observed_at": "2026-09-20T20:40:00Z",
              "remaining_percent": 57.4,
              "resets_at": "2026-09-20T21:45:00Z",
              "exhaustion_at": "2026-09-21T04:42:00Z",
              "coverage_hours": 24,
              "sample_count": 8
            }],
            "remaining_percent_points": 57.4,
            "effective_remaining_percent_points": 57.4,
            "current_workload_rate_percent_points_per_hour": 7.1,
            "coverage_hours": 24,
            "lookback_hours": 48,
            "measured_member_count": 1,
            "capacity_member_count": 1,
            "missing_rate_member_count": 0,
            "status": "estimated",
            "exhaustion_at": "2026-09-21T04:42:00Z",
            "diagnostics": [{ "code": "private_pool", "message": "private pool detail" }]
          }],
          "diagnostics": [{ "code": "private_snapshot", "message": "private snapshot detail" }]
        }
        """#.utf8)

        let forecast = try JSONDecoder().decode(UsageForecastSnapshot.self, from: data)

        XCTAssertEqual(forecast.accounts.count, 1)
        XCTAssertEqual(forecast.accounts[0].windows[0].usedPercent, 42.6)
        XCTAssertTrue(forecast.accounts[0].hasQualification)
        XCTAssertTrue(forecast.accounts[0].hasDiagnostics)
        XCTAssertTrue(forecast.pools[0].hasDiagnostics)
        XCTAssertTrue(forecast.hasDiagnostics)
        XCTAssertEqual(forecast.pools[0].members[0].label, "Personal")
    }

    func testForecastFormatterUsesServerStatusesAndSnapshotTime() {
        let now = Date(timeIntervalSince1970: 1_000)
        let steadyWindow = UsageForecastWindow(
            id: "window",
            name: "Window",
            windowSeconds: 3_600,
            usedPercent: 20,
            remainingPercent: 80,
            resetsAt: now.addingTimeInterval(86_400),
            status: "steady",
            coverage24hHours: 24,
            coverage48hHours: 24,
            sampleCount48h: 4,
            exhaustionAt: now.addingTimeInterval(7_200),
            hasDiagnostics: false
        )
        let account = UsageForecastAccount(
            accountID: "account",
            provider: "codex",
            plan: "Pro",
            generatedAt: now,
            status: "estimated",
            accountStatus: "ready",
            historySampleCount: 4,
            coverageHours: 24,
            lookbackHours: 48,
            latestObservedAt: now,
            currentSampleAgeSeconds: 30,
            exhaustionAt: now.addingTimeInterval(7_200),
            limitingWindowName: "Window",
            hasQualification: false,
            hasHistoryError: false,
            windows: [steadyWindow],
            hasDiagnostics: false
        )

        XCTAssertEqual(UsageForecastFormatters.accountHeadline(account, now: now), "~2 hr left")
        XCTAssertEqual(UsageForecastFormatters.accountHeadline(account, now: now.addingTimeInterval(60)), "~2 hr left")
        XCTAssertEqual(UsageForecastFormatters.runway(from: now.addingTimeInterval(120), now: now), "<1 hr left")

        let degraded = UsageForecastAccount(
            accountID: account.accountID,
            provider: account.provider,
            plan: account.plan,
            generatedAt: account.generatedAt,
            status: account.status,
            accountStatus: "degraded",
            historySampleCount: account.historySampleCount,
            coverageHours: account.coverageHours,
            lookbackHours: account.lookbackHours,
            latestObservedAt: account.latestObservedAt,
            currentSampleAgeSeconds: account.currentSampleAgeSeconds,
            exhaustionAt: account.exhaustionAt,
            limitingWindowName: account.limitingWindowName,
            hasQualification: account.hasQualification,
            hasHistoryError: account.hasHistoryError,
            windows: account.windows,
            hasDiagnostics: account.hasDiagnostics
        )
        XCTAssertEqual(UsageForecastFormatters.accountHeadline(degraded, now: now), "Account status limits estimate")

        let resetWindow = UsageForecastWindow(
            id: "window",
            name: "Window",
            windowSeconds: 3_600,
            usedPercent: 80,
            remainingPercent: 20,
            resetsAt: now.addingTimeInterval(1_800),
            status: "resets_before_exhaustion",
            coverage24hHours: 24,
            coverage48hHours: 24,
            sampleCount48h: 4,
            exhaustionAt: nil,
            hasDiagnostics: false
        )
        let resetAccount = UsageForecastAccount(
            accountID: account.accountID,
            provider: account.provider,
            plan: account.plan,
            generatedAt: now,
            status: "estimated",
            accountStatus: "ready",
            historySampleCount: 4,
            coverageHours: 24,
            lookbackHours: 48,
            latestObservedAt: now,
            currentSampleAgeSeconds: nil,
            exhaustionAt: nil,
            limitingWindowName: nil,
            hasQualification: false,
            hasHistoryError: false,
            windows: [resetWindow],
            hasDiagnostics: false
        )
        XCTAssertEqual(UsageForecastFormatters.accountHeadline(resetAccount, now: now), "Reset before depletion")

        let exhaustedMember = UsageForecastMember(accountID: "a", label: "A", status: "exhausted", observedAt: now, remainingPercent: 0, resetsAt: nil, exhaustionAt: now, coverageHours: 24, sampleCount: 4)
        let usableMember = UsageForecastMember(accountID: "b", label: "B", status: "steady", observedAt: now, remainingPercent: 50, resetsAt: nil, exhaustionAt: now.addingTimeInterval(21_600), coverageHours: 24, sampleCount: 4)
        let pool = UsageForecastPool(key: "pool", provider: "codex", plan: "Pro", planKnown: true, windowID: "window", windowName: "Window", windowSeconds: 3_600, compatibility: "same_capacity", comparable: true, members: [exhaustedMember, usableMember], remainingPercentPoints: 50, effectiveRemainingPercentPoints: 50, currentWorkloadRatePercentPointsPerHour: 8, coverageHours: 24, lookbackHours: 48, measuredMemberCount: 2, capacityMemberCount: 2, missingRateMemberCount: 0, status: "estimated", exhaustionAt: now.addingTimeInterval(21_600), hasDiagnostics: false)
        XCTAssertEqual(UsageForecastFormatters.poolHeadline(pool, now: now), "~6 hr left")
    }
}

@MainActor
final class DashboardModelTests: XCTestCase {
    func testRefreshFailurePreservesPreviousSnapshot() async throws {
        let service = StubService(responses: [.success(Self.snapshot), .failure])
        let store = StubConnectionStore(url: URL(string: "http://tunnel-host:8080")!)
        let model = DashboardModel(service: service, connectionStore: store)

        await model.loadIfNeeded()
        XCTAssertNotNil(model.snapshot)

        await model.refresh()

        XCTAssertTrue(model.refreshFailed)
        XCTAssertEqual(model.snapshot, Self.snapshot)
    }

    func testConnectingToAnotherServerClearsPreviousSnapshotBeforeLoading() async throws {
        let firstURL = URL(string: "http://one.example")!
        let secondURL = URL(string: "http://two.example")!
        let service = StubService(responses: [.success(Self.snapshot), .success(Self.snapshot)])
        let store = StubConnectionStore(url: firstURL)
        let model = DashboardModel(service: service, connectionStore: store)

        await model.loadIfNeeded()
        XCTAssertNotNil(model.snapshot)
        await model.connect(to: secondURL)

        XCTAssertEqual(model.savedBaseURL, secondURL)
        XCTAssertNotNil(model.snapshot)
        XCTAssertEqual(store.savedURL, secondURL)
    }

    func testForecastFailureClearsPreviousForecastAndPreservesUsage() async throws {
        let service = StubService(
            responses: [.success(Self.snapshot), .success(Self.snapshot)],
            forecastResponses: [.success(Self.snapshot), .failure]
        )
        let store = StubConnectionStore(url: URL(string: "http://tunnel-host:8080")!)
        let model = DashboardModel(service: service, connectionStore: store)

        await model.loadIfNeeded()
        XCTAssertNotNil(model.forecast)

        await model.refresh()

        XCTAssertEqual(model.snapshot, Self.snapshot)
        XCTAssertNil(model.forecast)
        XCTAssertTrue(model.forecastFailed)
    }

    func testOlderRefreshCannotOverwriteNewConnectionOrLeaveRefreshRunning() async throws {
        let firstURL = URL(string: "http://one.example")!
        let secondURL = URL(string: "http://two.example")!
        let service = DelayedService(first: Self.snapshot, second: Self.secondSnapshot)
        let store = StubConnectionStore(url: firstURL)
        let model = DashboardModel(service: service, connectionStore: store)

        await model.loadIfNeeded()
        let started = Task { await service.waitUntilRefreshStarted() }
        let refreshTask = Task { await model.refresh() }
        await started.value

        await model.connect(to: secondURL)
        await service.releaseRefresh()
        await refreshTask.value

        XCTAssertEqual(model.savedBaseURL, secondURL)
        XCTAssertEqual(model.snapshot, Self.secondSnapshot)
        XCTAssertFalse(model.isRefreshing)
        XCTAssertFalse(model.isLoading)
    }

    private static let snapshot = UsageSnapshot(
        generatedAt: Date(timeIntervalSince1970: 1_000),
        counts: SnapshotCounts(cache: 0, error: 0, live: 1, stale: 0),
        results: [UsageResult(accountID: "internal", status: .live, sample: UsageSample(accountID: "internal", provider: "Provider", label: "Account", plan: nil, observedAt: Date(timeIntervalSince1970: 900), ageSeconds: 100, windows: [UsageWindow(id: "window", name: "Window", usedPercent: 1, resetsAt: Date(timeIntervalSince1970: 2_000), windowSeconds: 3_600)], hasDiagnostics: false), hasError: false)]
    )

    private static let secondSnapshot = UsageSnapshot(
        generatedAt: Date(timeIntervalSince1970: 2_000),
        counts: SnapshotCounts(cache: 0, error: 0, live: 1, stale: 0),
        results: [UsageResult(accountID: "second", status: .live, sample: UsageSample(accountID: "second", provider: "Provider", label: "Second account", plan: nil, observedAt: Date(timeIntervalSince1970: 1_900), ageSeconds: 100, windows: [UsageWindow(id: "window", name: "Window", usedPercent: 2, resetsAt: Date(timeIntervalSince1970: 3_000), windowSeconds: 3_600)], hasDiagnostics: false), hasError: false)]
    )
}

private actor StubService: UsageServicing {
    enum Response: Sendable {
        case success(UsageSnapshot)
        case failure
    }

    var responses: [Response]
    var forecastResponses: [Response]

    init(responses: [Response], forecastResponses: [Response] = []) {
        self.responses = responses
        self.forecastResponses = forecastResponses
    }

    func fetchUsage(from _: URL) async throws -> UsageSnapshot {
        guard !responses.isEmpty else { throw UsageServiceError.requestFailed }
        switch responses.removeFirst() {
        case .success(let snapshot): return snapshot
        case .failure: throw UsageServiceError.requestFailed
        }
    }

    func fetchForecast(from _: URL) async throws -> UsageForecastSnapshot {
        guard !forecastResponses.isEmpty else { throw UsageServiceError.forecastUnavailable }
        switch forecastResponses.removeFirst() {
        case .success:
            return Self.forecast
        case .failure:
            throw UsageServiceError.requestFailed
        }
    }

    private static let forecast = UsageForecastSnapshot(generatedAt: Date(timeIntervalSince1970: 1_000), status: "estimated", accounts: [], pools: [], hasDiagnostics: false)
}

private final class StubConnectionStore: ConnectionStoring, @unchecked Sendable {
    let url: URL?
    private(set) var savedURL: URL?

    init(url: URL?) {
        self.url = url
    }

    func loadBaseURL() -> URL? { url }

    func saveBaseURL(_ url: URL) {
        savedURL = url
    }
}

private actor DelayedService: UsageServicing {
    private let first: UsageSnapshot
    private let second: UsageSnapshot
    private var usageCallCount = 0
    private var hasRefreshStarted = false
    private var refreshStarted: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    init(first: UsageSnapshot, second: UsageSnapshot) {
        self.first = first
        self.second = second
    }

    func fetchUsage(from baseURL: URL) async throws -> UsageSnapshot {
        usageCallCount += 1
        if usageCallCount == 2 {
            hasRefreshStarted = true
            refreshStarted?.resume()
            refreshStarted = nil
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }
        return baseURL.host == "two.example" ? second : first
    }

    func fetchForecast(from _: URL) async throws -> UsageForecastSnapshot {
        UsageForecastSnapshot(generatedAt: Date(timeIntervalSince1970: 1_000), status: "unavailable", accounts: [], pools: [], hasDiagnostics: false)
    }

    func waitUntilRefreshStarted() async {
        if hasRefreshStarted { return }
        await withCheckedContinuation { continuation in
            refreshStarted = continuation
        }
    }

    func releaseRefresh() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
