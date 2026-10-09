import Foundation
import Observation

@Observable
@MainActor
final class DashboardModel {
    private(set) var snapshot: UsageSnapshot?
    private(set) var forecast: UsageForecastSnapshot?
    private(set) var savedBaseURL: URL?
    private(set) var isLoading = false
    private(set) var isRefreshing = false
    private(set) var isForecastLoading = false
    private(set) var initialLoadFailed = false
    private(set) var refreshFailed = false
    private(set) var forecastFailed = false

    private let service: any UsageServicing
    private let connectionStore: any ConnectionStoring
    private var didAttemptInitialLoad = false
    private var loadGeneration = 0

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
        guard let savedBaseURL, !isLoading, !isRefreshing, !isForecastLoading else { return }
        await load(from: savedBaseURL, isManualRefresh: snapshot != nil)
    }

    func connect(to url: URL) async {
        loadGeneration += 1
        savedBaseURL = url
        connectionStore.saveBaseURL(url)
        snapshot = nil
        forecast = nil
        initialLoadFailed = false
        refreshFailed = false
        forecastFailed = false
        didAttemptInitialLoad = true
        await load(from: url, isManualRefresh: false)
    }

    private func load(from url: URL, isManualRefresh: Bool) async {
        loadGeneration += 1
        let generation = loadGeneration
        forecast = nil
        forecastFailed = false
        isForecastLoading = true
        if isManualRefresh {
            isLoading = false
            isRefreshing = true
            refreshFailed = false
        } else {
            isRefreshing = false
            isLoading = true
            initialLoadFailed = false
        }

        async let usageOutcome = fetchUsage(from: url)
        async let forecastOutcome = fetchForecast(from: url)
        let loadedUsage = await usageOutcome
        guard generation == loadGeneration else { return }

        var usageSucceeded = false
        switch loadedUsage {
        case .success(let loadedSnapshot):
            snapshot = loadedSnapshot
            initialLoadFailed = false
            refreshFailed = false
            usageSucceeded = true
        case .failure:
            if isManualRefresh {
                refreshFailed = true
            } else {
                initialLoadFailed = true
            }
        case .cancelled:
            // Cancellation leaves the current presentation untouched.
            isForecastLoading = false
        }

        if isManualRefresh {
            isRefreshing = false
        } else {
            isLoading = false
        }

        let loadedForecast = await forecastOutcome
        guard generation == loadGeneration else { return }
        isForecastLoading = false
        guard usageSucceeded else { return }

        switch loadedForecast {
        case .success(let loadedForecast):
            forecast = loadedForecast
            forecastFailed = false
        case .failure:
            forecast = nil
            forecastFailed = true
        case .cancelled:
            forecast = nil
        }
    }

    private func fetchUsage(from url: URL) async -> FetchOutcome<UsageSnapshot> {
        do {
            return .success(try await service.fetchUsage(from: url))
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failure
        }
    }

    private func fetchForecast(from url: URL) async -> FetchOutcome<UsageForecastSnapshot> {
        do {
            return .success(try await service.fetchForecast(from: url))
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failure
        }
    }
}

private enum FetchOutcome<Value: Sendable>: Sendable {
    case success(Value)
    case failure
    case cancelled
}
