import Foundation

protocol UsageServicing: Sendable {
    func fetchUsage(from baseURL: URL) async throws -> UsageSnapshot
    func fetchForecast(from baseURL: URL) async throws -> UsageForecastSnapshot
}

extension UsageServicing {
    func fetchForecast(from _: URL) async throws -> UsageForecastSnapshot {
        throw UsageServiceError.forecastUnavailable
    }
}

enum UsageServiceError: Error, Equatable {
    case invalidResponse
    case requestFailed
    case forecastUnavailable
}

struct URLSessionUsageService: UsageServicing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsage(from baseURL: URL) async throws -> UsageSnapshot {
        try await fetch(from: baseURL, path: "api/v1/usage", decode: UsageSnapshot.self)
    }

    func fetchForecast(from baseURL: URL) async throws -> UsageForecastSnapshot {
        try await fetch(from: baseURL, path: "api/v1/usage/forecast", decode: UsageForecastSnapshot.self)
    }

    private func fetch<T: Decodable>(from baseURL: URL, path: String, decode type: T.Type) async throws -> T {
        let endpoint = baseURL.appending(path: path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw UsageServiceError.invalidResponse
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as UsageServiceError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw UsageServiceError.requestFailed
        }
    }
}

protocol ConnectionStoring: Sendable {
    func loadBaseURL() -> URL?
    func saveBaseURL(_ url: URL)
}

final class UserDefaultsConnectionStore: ConnectionStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "seldon.connection.baseURL"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadBaseURL() -> URL? {
        guard let value = defaults.string(forKey: key) else { return nil }
        return ConnectionURL.parse(value)
    }

    func saveBaseURL(_ url: URL) {
        guard url.user == nil, url.password == nil else { return }
        defaults.set(url.absoluteString, forKey: key)
    }
}

enum ConnectionURL {
    static func parse(_ value: String) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil,
              url.user == nil,
              url.password == nil else {
            return nil
        }
        return url
    }
}
