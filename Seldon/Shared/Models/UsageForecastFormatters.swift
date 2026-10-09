import Foundation

enum UsageForecastFormatters {
    static func provider(_ value: String) -> String {
        switch value.lowercased() {
        case "codex": "Codex"
        case "claude": "Claude"
        default: value.capitalized
        }
    }

    static func accountHeadline(_ account: UsageForecastAccount, now: Date = .now) -> String {
        if account.accountStatus == "reauth_required" || account.status == "reauth_required" {
            return "Authentication required"
        }
        if account.hasHistoryError || account.status == "history_persistence_error" {
            return "History unavailable"
        }
        if account.accountStatus != "ready" {
            return "Account status limits estimate"
        }

        switch account.status {
        case "zero_burn":
            return "No observed burn"
        case "insufficient_history", "windows_missing", "plan_changed":
            return "Collecting history"
        case "stale":
            return "Stale estimate"
        case "estimated", "estimated_qualified":
            if account.windows.contains(where: { $0.status == "exhausted" }) {
                return "Exhausted"
            }
            if account.exhaustionAt == nil,
               account.windows.contains(where: { $0.status == "resets_before_exhaustion" }) {
                return "Reset before depletion"
            }
            if let exhaustionAt = account.exhaustionAt {
                if exhaustionAt <= now {
                    return "Estimated depleted"
                }
                return runway(from: exhaustionAt, now: now)
            }
            return "Estimate unavailable"
        default:
            return "Estimate unavailable"
        }
    }

    static func windowHeadline(_ window: UsageForecastWindow, now: Date = .now) -> String {
        switch window.status {
        case "exhausted":
            return "Exhausted"
        case "resets_before_exhaustion":
            return "Reset before depletion"
        case "zero_burn":
            return "No observed burn"
        case "insufficient_history", "gapped_history", "plan_changed":
            return "Collecting history"
        case "stale":
            return "Stale estimate"
        case "unknown_reset", "estimate_out_of_range":
            return "Estimate unavailable"
        case "steady":
            guard let exhaustionAt = window.exhaustionAt else { return "Estimate unavailable" }
            if exhaustionAt <= now { return "Estimate elapsed" }
            return runway(from: exhaustionAt, now: now)
        default:
            return "Estimate unavailable"
        }
    }

    static func poolHeadline(_ pool: UsageForecastPool, now: Date = .now) -> String {
        switch pool.status {
        case "reauth_required":
            return "Authentication required"
        case "zero_burn":
            return "No observed burn"
        case "resets_before_exhaustion":
            return "Reset before depletion"
        case "incomplete":
            if pool.members.contains(where: { $0.status == "stale" }) { return "Stale estimate" }
            if pool.members.contains(where: { $0.status == "account_degraded" }) { return "Account status limits estimate" }
            if pool.members.contains(where: { $0.status == "history_persistence_error" }) { return "History unavailable" }
            return pool.missingRateMemberCount > 0 ? "Estimate qualified" : "Estimate unavailable"
        case "estimated":
            guard let exhaustionAt = pool.exhaustionAt else { return "Estimate unavailable" }
            if exhaustionAt <= now { return "Estimated depleted" }
            return runway(from: exhaustionAt, now: now)
        default:
            return "Unavailable"
        }
    }

    static func memberHeadline(_ member: UsageForecastMember, now: Date = .now) -> String {
        switch member.status {
        case "exhausted":
            return "Exhausted"
        case "resets_before_exhaustion":
            return "Resets first"
        case "zero_burn":
            return "No observed burn"
        case "stale":
            return "Stale"
        case "reauth_required":
            return "Authentication required"
        case "account_degraded", "history_persistence_error":
            return "Estimate qualified"
        case "steady":
            guard let exhaustionAt = member.exhaustionAt else { return "Estimate unavailable" }
            if exhaustionAt <= now { return "Estimate elapsed" }
            return runway(from: exhaustionAt, now: now)
        default:
            return "Collecting history"
        }
    }

    static func runway(from date: Date, now: Date = .now) -> String {
        let rawSeconds = date.timeIntervalSince(now)
        guard rawSeconds.isFinite else { return "Estimate unavailable" }
        let seconds = min(max(0, rawSeconds), 365 * 24 * 3_600 * 100)
        let hours = seconds / 3_600
        if hours < 1 {
            return "<1 hr left"
        }
        if hours < 48 {
            let roundedHours = max(1, Int(hours.rounded()))
            return "~\(roundedHours) hr left"
        }
        let days = hours / 24
        if days < 14 {
            let roundedDays = max(1, Int(days.rounded()))
            return "~\(roundedDays) days left"
        }
        return "~\(Int(days.rounded())) days left"
    }

    static func coverage(_ hours: Double) -> String {
        guard hours.isFinite, hours > 0 else { return "No observed history" }
        if hours >= 24 {
            let days = hours / 24
            let value = days.rounded() == days ? String(Int(min(days, 10_000).rounded())) : days.formatted(.number.precision(.fractionLength(1)))
            return "Based on \(value) \(days == 1 ? "day" : "days") of observed history"
        }
        let value = hours.rounded() == hours ? String(Int(min(hours, 10_000).rounded())) : hours.formatted(.number.precision(.fractionLength(1)))
        return "Based on \(value) hr of observed history"
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1))) + "%"
    }

    static func planLine(provider: String, plan: String?) -> String {
        if let plan, !plan.isEmpty {
            return "\(UsageForecastFormatters.provider(provider)) · \(plan)"
        }
        return UsageForecastFormatters.provider(provider)
    }
}
