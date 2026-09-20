import Foundation

protocol UsageServicing: Sendable {
    func fetchUsage(from baseURL: URL) async throws -> UsageSnapshot
}

enum UsageServiceError: Error, Equatable {
    case invalidResponse
    case requestFailed
}

struct URLSessionUsageService: UsageServicing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsage(from baseURL: URL) async throws -> UsageSnapshot {
        let endpoint = baseURL.appending(path: "api/v1/usage")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw UsageServiceError.invalidResponse
            }
            return try JSONDecoder().decode(UsageSnapshot.self, from: data)
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
