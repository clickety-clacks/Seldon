import Foundation
import Observation

@Observable
@MainActor
final class DashboardModel {
    private(set) var snapshot: UsageSnapshot?
    private(set) var savedBaseURL: URL?
    private(set) var isLoading = false
    private(set) var isRefreshing = false
    private(set) var initialLoadFailed = false
    private(set) var refreshFailed = false

    private let service: any UsageServicing
    private let connectionStore: any ConnectionStoring
    private var didAttemptInitialLoad = false

    init(service: any UsageServicing, connectionStore: any ConnectionStoring) {
        self.service = service
        self.connectionStore = connectionStore
        savedBaseURL = connectionStore.loadBaseURL()
    }

    var hasConnection: Bool { savedBaseURL != nil }

    func loadIfNeeded() async {
        guard !didAttemptInitialLoad else { return }
        didAttemptInitialLoad = true
        guard let savedBaseURL else { return }
        await load(from: savedBaseURL, isManualRefresh: false)
    }

    func refresh() async {
        guard let savedBaseURL, !isLoading, !isRefreshing else { return }
        await load(from: savedBaseURL, isManualRefresh: snapshot != nil)
    }

    func connect(to url: URL) async {
        savedBaseURL = url
        connectionStore.saveBaseURL(url)
        snapshot = nil
        initialLoadFailed = false
        refreshFailed = false
        didAttemptInitialLoad = true
        await load(from: url, isManualRefresh: false)
    }

    private func load(from url: URL, isManualRefresh: Bool) async {
        if isManualRefresh {
            isRefreshing = true
            refreshFailed = false
        } else {
            isLoading = true
            initialLoadFailed = false
        }

        do {
            let loadedSnapshot = try await service.fetchUsage(from: url)
            snapshot = loadedSnapshot
            initialLoadFailed = false
            refreshFailed = false
        } catch is CancellationError {
            // Cancellation leaves the current presentation untouched.
        } catch {
            if isManualRefresh {
                refreshFailed = true
            } else {
                initialLoadFailed = true
            }
        }

        if isManualRefresh {
            isRefreshing = false
        } else {
            isLoading = false
        }
    }
}
