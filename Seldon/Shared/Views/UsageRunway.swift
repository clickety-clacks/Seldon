import SwiftUI

struct UsageRunway: View {
    let forecast: UsageForecastSnapshot
    let spacious: Bool

    private var poolColumns: [GridItem] {
        spacious ? [GridItem(.flexible(minimum: 280)), GridItem(.flexible(minimum: 280))] : [GridItem(.flexible())]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.md) {
            VStack(alignment: .leading, spacing: SeldonSpacing.xxs) {
                Text("Combined runway")
                    .font(.title2.weight(.semibold))
                HStack(alignment: .firstTextBaseline, spacing: SeldonSpacing.sm) {
                    Text("Server estimate")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("As of \(UsageFormatters.localDateTime(for: forecast.generatedAt))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if forecast.comparablePools.isEmpty {
                Text("No combined runway is available. Quotas stay separate by provider, plan, window, and duration.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(SeldonSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .seldonGroupBackground(cornerRadius: 16)
            } else {
                LazyVGrid(columns: poolColumns, alignment: .leading, spacing: SeldonSpacing.md) {
                    ForEach(forecast.comparablePools) { pool in
                        PoolRunwayCard(pool: pool, now: forecast.generatedAt)
                    }
                }
            }

            Text("Pools assume work can move between accounts with matching capacity. They are separate from each account's own runway.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AccountRunwaySummary: View {
    let account: UsageForecastAccount
    var allowsEstimate: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: SeldonSpacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(SeldonColors.accent)
                    .accessibilityHidden(true)
                Text("Runway")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: SeldonSpacing.sm)
                Text(headline)
                    .font(.title3.monospacedDigit().weight(.medium))
                    .foregroundStyle(headlineColor)
                    .multilineTextAlignment(.trailing)
            }
            if allowsEstimate,
               let limitingWindowName = account.limitingWindowName,
               account.exhaustionAt != nil {
                Text("Limited by \(limitingWindowName)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !allowsEstimate {
                Text("Current account sample unavailable")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if account.windows.contains(where: { $0.status == "resets_before_exhaustion" }) {
                    Text("One window resets before depletion.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if account.hasQualification || account.hasDiagnostics {
                    Text(account.hasQualification ? "Estimate qualified because some limits have no finite estimate." : "Estimate has limitations.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if account.status == "insufficient_history" || account.status == "windows_missing" {
                    Text("Collecting history from the usage server")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if account.status == "estimated", account.coverageHours.isFinite {
                    Text(UsageForecastFormatters.coverage(account.coverageHours))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, SeldonSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Runway, \(headline)")
        .accessibilityValue(Text(accessibilityDetail))
    }

    private var headline: String {
        allowsEstimate ? UsageForecastFormatters.accountHeadline(account, now: account.generatedAt) : "Account unavailable"
    }

    private var accessibilityDetail: String {
        if !allowsEstimate {
            return "Current account sample unavailable"
        }
        var details: [String] = []
        if account.windows.contains(where: { $0.status == "resets_before_exhaustion" }) {
            details.append("One window resets before depletion")
        }
        if account.hasQualification {
            details.append("Estimate qualified because some limits have no finite estimate")
        } else if account.hasDiagnostics {
            details.append("Estimate has limitations")
        }
        if !details.isEmpty {
            return details.joined(separator: ". ")
        }
        if account.status == "insufficient_history" || account.status == "windows_missing" {
            return "Collecting history from the usage server"
        }
        if account.status == "estimated", account.coverageHours.isFinite {
            return UsageForecastFormatters.coverage(account.coverageHours)
        }
        return ""
    }

    private var headlineColor: Color {
        switch account.status {
        case "estimated", "estimated_qualified": SeldonColors.accent
        case "zero_burn": .secondary
        case "reauth_required", "stale", "history_persistence_error": SeldonColors.attention
        default: .primary
        }
    }
}

private struct PoolRunwayCard: View {
    let pool: UsageForecastPool
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: SeldonSpacing.sm) {
                VStack(alignment: .leading, spacing: SeldonSpacing.xxs) {
                    Text(UsageForecastFormatters.poolHeadline(pool, now: now))
                        .font(.title3.monospacedDigit().weight(.medium))
                        .foregroundStyle(headlineColor)
                    Text(UsageForecastFormatters.planLine(provider: pool.provider, plan: pool.plan))
                        .font(.headline)
                        .lineLimit(nil)
                }
                Spacer(minLength: SeldonSpacing.sm)
                Text("\(pool.members.count) \(pool.members.count == 1 ? "account" : "accounts")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            Text(pool.windowName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(nil)

            VStack(alignment: .leading, spacing: SeldonSpacing.xxs) {
                ForEach(pool.members) { member in
                    HStack(alignment: .firstTextBaseline, spacing: SeldonSpacing.sm) {
                        Text(member.label)
                            .font(.subheadline)
                            .lineLimit(nil)
                        Spacer(minLength: SeldonSpacing.sm)
                        Text(UsageForecastFormatters.memberHeadline(member, now: now))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Divider()
                .overlay(SeldonColors.separator)
            if pool.hasDiagnostics {
                Text("Estimate has limitations.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("Assumes work can move between these accounts.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SeldonSpacing.md)
        .seldonGroupBackground()
        .accessibilityElement(children: .contain)
    }

    private var headlineColor: Color {
        switch pool.status {
        case "estimated": SeldonColors.accent
        case "zero_burn": .secondary
        case "reauth_required", "incomplete": SeldonColors.attention
        default: .primary
        }
    }
}

struct UsageRunwayUnavailable: View {
    let isLoading: Bool

    var body: some View {
        HStack(alignment: .top, spacing: SeldonSpacing.sm) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "chart.line.flattrend.xyaxis")
            }
            VStack(alignment: .leading, spacing: SeldonSpacing.xxs) {
                Text(isLoading ? "Loading usage runway" : "Usage runway unavailable")
                    .font(.headline)
                Text(isLoading ? "The server forecast is being read." : "Current usage remains available. Refresh to try the server forecast again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SeldonSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .seldonGroupBackground(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}
