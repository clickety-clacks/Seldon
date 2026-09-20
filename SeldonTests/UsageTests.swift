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
