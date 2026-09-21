import Foundation

/// The forecast endpoint intentionally has a separate model from the current
/// usage snapshot. A forecast is useful only when it arrived with the same
/// refresh generation as the snapshot beside it.
struct UsageForecastWindow: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let windowSeconds: Int64?
    let usedPercent: Double
    let remainingPercent: Double
    let resetsAt: Date?
    let status: String
    let coverage24hHours: Double
    let coverage48hHours: Double
    let sampleCount48h: Int
    let exhaustionAt: Date?
    let hasDiagnostics: Bool

    var isResetBound: Bool { status == "resets_before_exhaustion" }
}

struct UsageForecastAccount: Identifiable, Equatable, Sendable {
    let accountID: String
    let provider: String
    let plan: String?
    let generatedAt: Date
    let status: String
    let accountStatus: String
    let historySampleCount: Int
    let coverageHours: Double
    let lookbackHours: Double
    let latestObservedAt: Date?
    let currentSampleAgeSeconds: Int64?
    let exhaustionAt: Date?
    let limitingWindowName: String?
    let hasQualification: Bool
    let hasHistoryError: Bool
    let windows: [UsageForecastWindow]
    let hasDiagnostics: Bool

    var id: String { accountID }
}

struct UsageForecastMember: Identifiable, Equatable, Sendable {
    let accountID: String
    let label: String
    let status: String
    let observedAt: Date?
    let remainingPercent: Double
    let resetsAt: Date?
    let exhaustionAt: Date?
    let coverageHours: Double
    let sampleCount: Int

    var id: String { accountID }
}

struct UsageForecastPool: Identifiable, Equatable, Sendable {
    let key: String
    let provider: String
    let plan: String?
    let planKnown: Bool
    let windowID: String
    let windowName: String
    let windowSeconds: Int64?
    let compatibility: String
    let comparable: Bool
    let members: [UsageForecastMember]
    let remainingPercentPoints: Double
    let effectiveRemainingPercentPoints: Double
    let currentWorkloadRatePercentPointsPerHour: Double?
    let coverageHours: Double
    let lookbackHours: Double
    let measuredMemberCount: Int
    let capacityMemberCount: Int
    let missingRateMemberCount: Int
    let status: String
    let exhaustionAt: Date?
    let hasDiagnostics: Bool

    var id: String { key }
}

struct UsageForecastSnapshot: Equatable, Sendable {
    let generatedAt: Date
    let status: String
    let accounts: [UsageForecastAccount]
    let pools: [UsageForecastPool]
    let hasDiagnostics: Bool

    var comparablePools: [UsageForecastPool] { pools.filter(\.comparable) }
}

enum ForecastDecodingError: Error, Equatable {
    case invalidTimestamp(String)
}

private enum ForecastCoding {
    static func date(_ value: String) throws -> Date {
        do {
            return try TimestampCodec.date(from: value)
        } catch {
            throw ForecastDecodingError.invalidTimestamp(value)
        }
    }

    static func optionalDate(_ value: String?) throws -> Date? {
        guard let value else { return nil }
        return try date(value)
    }

    static func diagnosticsPresent<C: KeyedDecodingContainerProtocol>(in container: C, key: C.Key) throws -> Bool {
        guard container.contains(key), try !container.decodeNil(forKey: key) else { return false }
        var diagnostics = try container.nestedUnkeyedContainer(forKey: key)
        return !diagnostics.isAtEnd
    }
}

extension UsageForecastSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case status
        case accounts
        case pools
        case diagnostics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try ForecastCoding.date(container.decode(String.self, forKey: .generatedAt))
        status = try container.decode(String.self, forKey: .status)
        accounts = try container.decode([UsageForecastAccount].self, forKey: .accounts)
        pools = try container.decode([UsageForecastPool].self, forKey: .pools)
        hasDiagnostics = try ForecastCoding.diagnosticsPresent(in: container, key: .diagnostics)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ISO8601DateFormatter().string(from: generatedAt), forKey: .generatedAt)
        try container.encode(status, forKey: .status)
        try container.encode(accounts, forKey: .accounts)
        try container.encode(pools, forKey: .pools)
        if hasDiagnostics { try container.encode(["reported"], forKey: .diagnostics) }
    }
}

extension UsageForecastAccount: Codable {
    private enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case provider
        case plan
        case generatedAt = "generated_at"
        case status
        case accountStatus = "account_status"
        case historySampleCount = "history_sample_count"
        case coverageHours = "coverage_hours"
        case lookbackHours = "lookback_hours"
        case latestObservedAt = "latest_observed_at"
        case currentSampleAgeSeconds = "current_sample_age_seconds"
        case exhaustionAt = "exhaustion_at"
        case limitingWindowName = "limiting_window_name"
        case qualification
        case historyError = "history_error"
        case windows
        case diagnostics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountID = try container.decode(String.self, forKey: .accountID)
        provider = try container.decode(String.self, forKey: .provider)
        plan = try container.decodeIfPresent(String.self, forKey: .plan)
        generatedAt = try ForecastCoding.date(container.decode(String.self, forKey: .generatedAt))
        status = try container.decode(String.self, forKey: .status)
        accountStatus = try container.decode(String.self, forKey: .accountStatus)
        historySampleCount = try container.decode(Int.self, forKey: .historySampleCount)
        coverageHours = try container.decode(Double.self, forKey: .coverageHours)
        lookbackHours = try container.decode(Double.self, forKey: .lookbackHours)
        latestObservedAt = try ForecastCoding.optionalDate(container.decodeIfPresent(String.self, forKey: .latestObservedAt))
        currentSampleAgeSeconds = try container.decodeIfPresent(Int64.self, forKey: .currentSampleAgeSeconds)
        exhaustionAt = try ForecastCoding.optionalDate(container.decodeIfPresent(String.self, forKey: .exhaustionAt))
        limitingWindowName = try container.decodeIfPresent(String.self, forKey: .limitingWindowName)
        if container.contains(.qualification), try !container.decodeNil(forKey: .qualification) {
            let qualification = try container.decode(String.self, forKey: .qualification)
            hasQualification = !qualification.isEmpty
        } else {
            hasQualification = false
        }
        if container.contains(.historyError), try !container.decodeNil(forKey: .historyError) {
            let historyError = try container.decode(String.self, forKey: .historyError)
            hasHistoryError = !historyError.isEmpty
        } else {
            hasHistoryError = false
        }
        windows = try container.decode([UsageForecastWindow].self, forKey: .windows)
        hasDiagnostics = try ForecastCoding.diagnosticsPresent(in: container, key: .diagnostics)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountID, forKey: .accountID)
        try container.encode(provider, forKey: .provider)
        try container.encodeIfPresent(plan, forKey: .plan)
        try container.encode(ISO8601DateFormatter().string(from: generatedAt), forKey: .generatedAt)
        try container.encode(status, forKey: .status)
        try container.encode(accountStatus, forKey: .accountStatus)
        try container.encode(historySampleCount, forKey: .historySampleCount)
        try container.encode(coverageHours, forKey: .coverageHours)
        try container.encode(lookbackHours, forKey: .lookbackHours)
        try container.encodeIfPresent(latestObservedAt.map { ISO8601DateFormatter().string(from: $0) }, forKey: .latestObservedAt)
        try container.encodeIfPresent(currentSampleAgeSeconds, forKey: .currentSampleAgeSeconds)
        try container.encodeIfPresent(exhaustionAt.map { ISO8601DateFormatter().string(from: $0) }, forKey: .exhaustionAt)
        try container.encodeIfPresent(limitingWindowName, forKey: .limitingWindowName)
        if hasQualification { try container.encode("reported", forKey: .qualification) }
        if hasHistoryError { try container.encode("reported", forKey: .historyError) }
        try container.encode(windows, forKey: .windows)
        if hasDiagnostics { try container.encode(["reported"], forKey: .diagnostics) }
    }
}

extension UsageForecastWindow: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case windowSeconds = "window_seconds"
        case usedPercent = "used_percent"
        case remainingPercent = "remaining_percent"
        case resetsAt = "resets_at"
        case status
        case coverage24hHours = "coverage_24h_hours"
        case coverage48hHours = "coverage_48h_hours"
        case sampleCount48h = "sample_count_48h"
        case exhaustionAt = "exhaustion_at"
        case diagnostics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        windowSeconds = try container.decodeIfPresent(Int64.self, forKey: .windowSeconds)
        usedPercent = try container.decode(Double.self, forKey: .usedPercent)
        remainingPercent = try container.decode(Double.self, forKey: .remainingPercent)
        resetsAt = try ForecastCoding.optionalDate(container.decodeIfPresent(String.self, forKey: .resetsAt))
        status = try container.decode(String.self, forKey: .status)
        coverage24hHours = try container.decode(Double.self, forKey: .coverage24hHours)
        coverage48hHours = try container.decode(Double.self, forKey: .coverage48hHours)
        sampleCount48h = try container.decode(Int.self, forKey: .sampleCount48h)
        exhaustionAt = try ForecastCoding.optionalDate(container.decodeIfPresent(String.self, forKey: .exhaustionAt))
        hasDiagnostics = try ForecastCoding.diagnosticsPresent(in: container, key: .diagnostics)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(windowSeconds, forKey: .windowSeconds)
        try container.encode(usedPercent, forKey: .usedPercent)
        try container.encode(remainingPercent, forKey: .remainingPercent)
        try container.encodeIfPresent(resetsAt.map { ISO8601DateFormatter().string(from: $0) }, forKey: .resetsAt)
        try container.encode(status, forKey: .status)
        try container.encode(coverage24hHours, forKey: .coverage24hHours)
        try container.encode(coverage48hHours, forKey: .coverage48hHours)
        try container.encode(sampleCount48h, forKey: .sampleCount48h)
        try container.encodeIfPresent(exhaustionAt.map { ISO8601DateFormatter().string(from: $0) }, forKey: .exhaustionAt)
        if hasDiagnostics { try container.encode(["reported"], forKey: .diagnostics) }
    }
}

extension UsageForecastPool: Codable {
    private enum CodingKeys: String, CodingKey {
        case key
        case provider
        case plan
        case planKnown = "plan_known"
        case windowID = "window_id"
        case windowName = "window_name"
        case windowSeconds = "window_seconds"
        case compatibility
        case comparable
        case members
        case remainingPercentPoints = "remaining_percent_points"
        case effectiveRemainingPercentPoints = "effective_remaining_percent_points"
        case currentWorkloadRatePercentPointsPerHour = "current_workload_rate_percent_points_per_hour"
        case coverageHours = "coverage_hours"
        case lookbackHours = "lookback_hours"
        case measuredMemberCount = "measured_member_count"
        case capacityMemberCount = "capacity_member_count"
        case missingRateMemberCount = "missing_rate_member_count"
        case status
        case exhaustionAt = "exhaustion_at"
        case diagnostics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        provider = try container.decode(String.self, forKey: .provider)
        plan = try container.decodeIfPresent(String.self, forKey: .plan)
        planKnown = try container.decode(Bool.self, forKey: .planKnown)
        windowID = try container.decode(String.self, forKey: .windowID)
        windowName = try container.decode(String.self, forKey: .windowName)
        windowSeconds = try container.decodeIfPresent(Int64.self, forKey: .windowSeconds)
        compatibility = try container.decode(String.self, forKey: .compatibility)
        comparable = try container.decode(Bool.self, forKey: .comparable)
        members = try container.decode([UsageForecastMember].self, forKey: .members)
        remainingPercentPoints = try container.decode(Double.self, forKey: .remainingPercentPoints)
        effectiveRemainingPercentPoints = try container.decode(Double.self, forKey: .effectiveRemainingPercentPoints)
        currentWorkloadRatePercentPointsPerHour = try container.decodeIfPresent(Double.self, forKey: .currentWorkloadRatePercentPointsPerHour)
        coverageHours = try container.decode(Double.self, forKey: .coverageHours)
        lookbackHours = try container.decode(Double.self, forKey: .lookbackHours)
        measuredMemberCount = try container.decode(Int.self, forKey: .measuredMemberCount)
        capacityMemberCount = try container.decode(Int.self, forKey: .capacityMemberCount)
        missingRateMemberCount = try container.decode(Int.self, forKey: .missingRateMemberCount)
        status = try container.decode(String.self, forKey: .status)
        exhaustionAt = try ForecastCoding.optionalDate(container.decodeIfPresent(String.self, forKey: .exhaustionAt))
        hasDiagnostics = try ForecastCoding.diagnosticsPresent(in: container, key: .diagnostics)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(provider, forKey: .provider)
        try container.encodeIfPresent(plan, forKey: .plan)
        try container.encode(planKnown, forKey: .planKnown)
        try container.encode(windowID, forKey: .windowID)
        try container.encode(windowName, forKey: .windowName)
        try container.encodeIfPresent(windowSeconds, forKey: .windowSeconds)
        try container.encode(compatibility, forKey: .compatibility)
        try container.encode(comparable, forKey: .comparable)
        try container.encode(members, forKey: .members)
        try container.encode(remainingPercentPoints, forKey: .remainingPercentPoints)
        try container.encode(effectiveRemainingPercentPoints, forKey: .effectiveRemainingPercentPoints)
        try container.encodeIfPresent(currentWorkloadRatePercentPointsPerHour, forKey: .currentWorkloadRatePercentPointsPerHour)
        try container.encode(coverageHours, forKey: .coverageHours)
        try container.encode(lookbackHours, forKey: .lookbackHours)
        try container.encode(measuredMemberCount, forKey: .measuredMemberCount)
        try container.encode(capacityMemberCount, forKey: .capacityMemberCount)
        try container.encode(missingRateMemberCount, forKey: .missingRateMemberCount)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(exhaustionAt.map { ISO8601DateFormatter().string(from: $0) }, forKey: .exhaustionAt)
        if hasDiagnostics { try container.encode(["reported"], forKey: .diagnostics) }
    }
}

extension UsageForecastMember: Codable {
    private enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case label
        case status
        case observedAt = "observed_at"
        case remainingPercent = "remaining_percent"
        case resetsAt = "resets_at"
        case exhaustionAt = "exhaustion_at"
        case coverageHours = "coverage_hours"
        case sampleCount = "sample_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountID = try container.decode(String.self, forKey: .accountID)
        label = try container.decode(String.self, forKey: .label)
        status = try container.decode(String.self, forKey: .status)
        observedAt = try ForecastCoding.optionalDate(container.decodeIfPresent(String.self, forKey: .observedAt))
        remainingPercent = try container.decode(Double.self, forKey: .remainingPercent)
        resetsAt = try ForecastCoding.optionalDate(container.decodeIfPresent(String.self, forKey: .resetsAt))
        exhaustionAt = try ForecastCoding.optionalDate(container.decodeIfPresent(String.self, forKey: .exhaustionAt))
        coverageHours = try container.decode(Double.self, forKey: .coverageHours)
        sampleCount = try container.decode(Int.self, forKey: .sampleCount)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountID, forKey: .accountID)
        try container.encode(label, forKey: .label)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(observedAt.map { ISO8601DateFormatter().string(from: $0) }, forKey: .observedAt)
        try container.encode(remainingPercent, forKey: .remainingPercent)
        try container.encodeIfPresent(resetsAt.map { ISO8601DateFormatter().string(from: $0) }, forKey: .resetsAt)
        try container.encodeIfPresent(exhaustionAt.map { ISO8601DateFormatter().string(from: $0) }, forKey: .exhaustionAt)
        try container.encode(coverageHours, forKey: .coverageHours)
        try container.encode(sampleCount, forKey: .sampleCount)
    }
}
