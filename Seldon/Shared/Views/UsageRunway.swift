import SwiftUI

struct UsageRunway: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let forecast: UsageForecastSnapshot
    let spacious: Bool

    private var poolColumns: [GridItem] {
        [GridItem(.adaptive(minimum: spacious ? 360 : 260), spacing: SeldonSpacing.sm)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) { sectionTitle; assumption }
            } else {
                HStack(alignment: .firstTextBaseline) { sectionTitle; Spacer(); assumption }
            }
            if forecast.comparablePools.isEmpty {
                Text("No compatible account pools")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: poolColumns, alignment: .leading, spacing: SeldonSpacing.sm) {
                    ForEach(forecast.comparablePools) { pool in
                        PoolRunwayCard(pool: pool, now: forecast.generatedAt)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionTitle: some View {
        Text("Combined runway").font(.subheadline.weight(.semibold))
    }

    private var assumption: some View {
        Text("If switching accounts").font(.caption).foregroundStyle(.secondary)
    }

}

/// A small, reusable estimate alongside current usage. Qualifications remain
/// visible here; the full explanation belongs in the account's disclosure.
struct AccountRunwaySummary: View {
    let account: UsageForecastAccount
    var allowsEstimate: Bool = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(allowsEstimate ? UsageForecastFormatters.accountHeadline(account, now: account.generatedAt) : "Account unavailable")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(headlineColor)
                .fixedSize(horizontal: false, vertical: true)
            if allowsEstimate {
                if account.hasQualification || account.hasDiagnostics {
                    Label(account.hasQualification ? "Qualified estimate" : "Estimate has limits", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(SeldonColors.attention)
                } else if account.windows.count > 1, let name = account.limitingWindowName, account.exhaustionAt != nil {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if account.exhaustionAt != nil, account.windows.contains(where: { $0.isResetBound }) {
                    Text("Another limit resets first")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .multilineTextAlignment(.trailing)
        .accessibilityElement(children: .combine)
    }

    private var headlineColor: Color {
        guard allowsEstimate else { return .secondary }
        switch account.status {
        case "estimated", "estimated_qualified":
            return account.windows.contains(where: { $0.status == "exhausted" }) ? SeldonColors.attention : SeldonColors.accent
        case "reauth_required", "stale", "history_persistence_error":
            return SeldonColors.attention
        default:
            return .secondary
        }
    }
}

private struct PoolRunwayCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isExpanded = false
    let pool: UsageForecastPool
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
                            identity
                            estimate
                            chevron
                        }
                    } else {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: SeldonSpacing.sm) {
                                identity
                                Spacer(minLength: 0)
                                estimate
                                chevron
                            }
                            VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
                                identity
                                HStack { estimate; Spacer(); chevron }
                            }
                        }
                    }
                }
                .padding(SeldonSpacing.sm)
                .frame(minHeight: SeldonControls.minimumTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(UsageForecastFormatters.planLine(provider: pool.provider, plan: pool.plan)), \(pool.windowName), \(UsageForecastFormatters.poolHeadline(pool, now: now))")
            .accessibilityValue((pool.hasDiagnostics ? "Qualified estimate. " : "") + (isExpanded ? "Expanded" : "Collapsed"))
            .accessibilityHint("Shows pool members and assumptions")

            if isExpanded {
                VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
                    Divider()
                    Text(pool.members.map(\.label).joined(separator: " · "))
                        .font(.subheadline)
                    Text("Assumes work can move between accounts with matching provider, plan, and quota window. Each account keeps its own limits.")
                    if pool.hasDiagnostics {
                        Text("Some capacity or demand is uncertain. Treat this estimate as qualified.")
                            .foregroundStyle(SeldonColors.attention)
                    }
                    Text(UsageForecastFormatters.coverage(pool.coverageHours))
                    Text("Estimate as of \(UsageFormatters.localDateTime(for: now))")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding([.horizontal, .bottom], SeldonSpacing.sm)
            }
        }
        .seldonGroupBackground(cornerRadius: 12)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(UsageForecastFormatters.planLine(provider: pool.provider, plan: pool.plan))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(pool.windowName) · \(pool.members.count) \(pool.members.count == 1 ? "account" : "accounts")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var estimate: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(UsageForecastFormatters.poolHeadline(pool, now: now))
                .font(.headline.monospacedDigit())
                .foregroundStyle(pool.status == "estimated" ? SeldonColors.accent : .secondary)
            if pool.hasDiagnostics && UsageForecastFormatters.poolHeadline(pool, now: now) != "Estimate qualified" {
                Text("Qualified")
                    .font(.caption)
                    .foregroundStyle(SeldonColors.attention)
            }
        }
        .multilineTextAlignment(.trailing)
    }

    private var chevron: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
}

struct UsageRunwayUnavailable: View {
    let isLoading: Bool

    var body: some View {
        HStack(spacing: SeldonSpacing.xs) {
            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "chart.line.flattrend.xyaxis")
            }
            Text(isLoading ? "Loading runway estimates" : "Runway estimates unavailable")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
