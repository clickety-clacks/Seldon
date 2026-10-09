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

    func testDecodesNullResetTimestampForStaleClaudeSample() throws {
        let data = Data(#"""
        {
          "generated_at": "2026-10-09T20:42:00Z",
          "counts": { "cache": 0, "error": 0, "live": 0, "stale": 1 },
          "results": [{
            "account_id": "claude-1",
            "status": "stale",
            "sample": {
              "account_id": "claude-1",
              "provider": "Claude",
              "label": "Claude account",
              "observed_at": "2026-10-09T20:40:00Z",
              "age_seconds": 7200,
              "windows": [{
                "id": "five-hour",
                "name": "Five-hour window",
                "used_percent": 42.6,
                "resets_at": null,
                "window_seconds": 18000
              }]
            }
          }]
        }
        """#.utf8)

        let snapshot = try JSONDecoder().decode(UsageSnapshot.self, from: data)

        XCTAssertEqual(snapshot.results[0].status, .stale)
        XCTAssertNil(snapshot.results[0].sample?.windows[0].resetsAt)
        XCTAssertEqual(UsageFormatters.resetText(for: snapshot.results[0].sample?.windows[0].resetsAt), "Not reported")
        XCTAssertEqual(UsageFormatters.resetAccessibilityText(for: snapshot.results[0].sample?.windows[0].resetsAt), "reset time not reported")
    }

    func testDecodesOmittedResetTimestamp() throws {
        let data = Data(#"""
        {
          "id": "weekly",
          "name": "Weekly window",
          "used_percent": 9,
          "window_seconds": 604800
        }
        """#.utf8)

        let window = try JSONDecoder().decode(UsageWindow.self, from: data)

        XCTAssertNil(window.resetsAt)
    }

    @MainActor
    func testAgendaIncludesOnlyReportedResetTimestamps() {
        let unreported = UsageWindow(id: "five-hour", name: "Five-hour window", usedPercent: 42.6, resetsAt: nil, windowSeconds: 18_000)
        let reported = UsageWindow(id: "weekly", name: "Weekly window", usedPercent: 9, resetsAt: Date(timeIntervalSince1970: 2_000), windowSeconds: 604_800)
        let sample = UsageSample(accountID: "account", provider: "Claude", label: "Claude account", plan: nil, observedAt: Date(timeIntervalSince1970: 1_000), ageSeconds: 60, windows: [unreported, reported], hasDiagnostics: false)
        let results = [UsageResult(accountID: "account", status: .stale, sample: sample, hasError: false)]

        XCTAssertEqual(ResetAgenda.reportedEntries(from: results).map(\.windowName), ["Weekly window"])
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

    private static let snapshot = UsageSnapshot(
        generatedAt: Date(timeIntervalSince1970: 1_000),
        counts: SnapshotCounts(cache: 0, error: 0, live: 1, stale: 0),
        results: [UsageResult(accountID: "internal", status: .live, sample: UsageSample(accountID: "internal", provider: "Provider", label: "Account", plan: nil, observedAt: Date(timeIntervalSince1970: 900), ageSeconds: 100, windows: [UsageWindow(id: "window", name: "Window", usedPercent: 1, resetsAt: Date(timeIntervalSince1970: 2_000), windowSeconds: 3_600)], hasDiagnostics: false), hasError: false)]
    )
}

private actor StubService: UsageServicing {
    enum Response: Sendable {
        case success(UsageSnapshot)
        case failure
    }

    var responses: [Response]

    init(responses: [Response]) {
        self.responses = responses
    }

    func fetchUsage(from _: URL) async throws -> UsageSnapshot {
        guard !responses.isEmpty else { throw UsageServiceError.requestFailed }
        switch responses.removeFirst() {
        case .success(let snapshot): return snapshot
        case .failure: throw UsageServiceError.requestFailed
        }
    }
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
