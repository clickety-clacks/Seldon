import Foundation

enum SourceStatus: String, Codable, Sendable, CaseIterable {
    case live
    case cache
    case stale
    case error

    var displayName: String {
        switch self {
        case .live: "Live"
        case .cache: "Cached"
        case .stale: "Stale"
        case .error: "Error"
        }
    }
}

struct SnapshotCounts: Codable, Equatable, Sendable {
    let cache: Int
    let error: Int
    let live: Int
    let stale: Int

    var nonZeroSummary: [(SourceStatus, Int)] {
        let values: [(SourceStatus, Int)] = [(.live, live), (.cache, cache), (.stale, stale), (.error, error)]
        if values.allSatisfy({ $0.1 == 0 }) {
            return values
        }
        return values.filter { $0.1 != 0 }
    }
}

struct UsageWindow: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let usedPercent: Double
    let resetsAt: Date
    let windowSeconds: Double
}

struct UsageSample: Equatable, Sendable {
    let accountID: String
    let provider: String
    let label: String
    let plan: String?
    let observedAt: Date
    let ageSeconds: Double
    let windows: [UsageWindow]
    let hasDiagnostics: Bool
}

struct UsageResult: Identifiable, Equatable, Sendable {
    let accountID: String
    let status: SourceStatus
    let sample: UsageSample?
    let hasError: Bool

    var id: String { accountID }
}

struct UsageSnapshot: Equatable, Sendable {
    let generatedAt: Date
    let counts: SnapshotCounts
    let results: [UsageResult]
}

enum UsageDecodingError: Error, Equatable {
    case invalidTimestamp(String)
}

enum TimestampCodec {
    static func date(from value: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return date
        }
        throw UsageDecodingError.invalidTimestamp(value)
    }
}

extension UsageSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case counts
        case results
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try TimestampCodec.date(from: container.decode(String.self, forKey: .generatedAt))
        counts = try container.decode(SnapshotCounts.self, forKey: .counts)
        results = try container.decode([UsageResult].self, forKey: .results)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ISO8601DateFormatter().string(from: generatedAt), forKey: .generatedAt)
        try container.encode(counts, forKey: .counts)
        try container.encode(results, forKey: .results)
    }
}

extension UsageResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case status
        case sample
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountID = try container.decode(String.self, forKey: .accountID)
        status = try container.decode(SourceStatus.self, forKey: .status)
        sample = try container.decodeIfPresent(UsageSample.self, forKey: .sample)
        if container.contains(.error) {
            hasError = try !container.decodeNil(forKey: .error)
        } else {
            hasError = false
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountID, forKey: .accountID)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(sample, forKey: .sample)
        if hasError { try container.encode("reported", forKey: .error) }
    }
}

extension UsageSample: Codable {
    private enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case provider
        case label
        case plan
        case observedAt = "observed_at"
        case ageSeconds = "age_seconds"
        case windows
        case diagnostics
        case raw
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountID = try container.decode(String.self, forKey: .accountID)
        provider = try container.decode(String.self, forKey: .provider)
        label = try container.decode(String.self, forKey: .label)
        plan = try container.decodeIfPresent(String.self, forKey: .plan)
        observedAt = try TimestampCodec.date(from: container.decode(String.self, forKey: .observedAt))
        ageSeconds = try container.decode(Double.self, forKey: .ageSeconds)
        windows = try container.decode([UsageWindow].self, forKey: .windows)

        if container.contains(.diagnostics) {
            let diagnostics = try container.nestedUnkeyedContainer(forKey: .diagnostics)
            hasDiagnostics = !diagnostics.isAtEnd
        } else {
            hasDiagnostics = false
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountID, forKey: .accountID)
        try container.encode(provider, forKey: .provider)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(plan, forKey: .plan)
        try container.encode(ISO8601DateFormatter().string(from: observedAt), forKey: .observedAt)
        try container.encode(ageSeconds, forKey: .ageSeconds)
        try container.encode(windows, forKey: .windows)
        if hasDiagnostics { try container.encode(["reported"], forKey: .diagnostics) }
    }
}

extension UsageWindow: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case usedPercent = "used_percent"
        case resetsAt = "resets_at"
        case windowSeconds = "window_seconds"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        usedPercent = try container.decode(Double.self, forKey: .usedPercent)
        resetsAt = try TimestampCodec.date(from: container.decode(String.self, forKey: .resetsAt))
        windowSeconds = try container.decode(Double.self, forKey: .windowSeconds)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(usedPercent, forKey: .usedPercent)
        try container.encode(ISO8601DateFormatter().string(from: resetsAt), forKey: .resetsAt)
        try container.encode(windowSeconds, forKey: .windowSeconds)
    }
}
