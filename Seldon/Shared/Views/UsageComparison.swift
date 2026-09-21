import SwiftUI

struct UsageComparison: View {
    let results: [UsageResult]
    let forecast: UsageForecastSnapshot? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.lg) {
            comparisonHeader
            ForEach(results) { result in
                comparisonSection(result)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var comparisonHeader: some View {
        HStack(alignment: .bottom, spacing: SeldonSpacing.sm) {
            Text("ACCOUNT / WINDOW")
                .frame(minWidth: 160, alignment: .leading)
            Text("USED")
                .frame(width: 80, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text("UTILIZATION")
                HStack {
                    Text("0%")
                    Spacer()
                    Text("50%")
                    Spacer()
                    Text("100%")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
            Text("RESET")
                .frame(width: 136, alignment: .leading)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func comparisonSection(_ result: UsageResult) -> some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: SeldonSpacing.xxs) {
                    Text(result.sample?.label ?? "Account unavailable")
                        .font(.headline)
                        .lineLimit(nil)
                    if let sample = result.sample {
                        HStack(spacing: SeldonSpacing.xs) {
                            Text(sample.provider)
                            if let plan = sample.plan, !plan.isEmpty {
                                Text("·")
                                Text(plan)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: SeldonSpacing.sm)
                SourceStatusBadge(status: result.status)
            }

            if let sample = result.sample {
                if let accountForecast = forecast?.accounts.first(where: { $0.accountID == result.accountID }), result.status != .error {
                    AccountRunwaySummary(account: accountForecast)
                }
                ForEach(sample.windows) { window in
                    HStack(alignment: .firstTextBaseline, spacing: SeldonSpacing.sm) {
                        Text(window.name)
                            .frame(minWidth: 160, alignment: .leading)
                        Text(UsageFormatters.percent(window.usedPercent))
                            .font(.title3.monospacedDigit().weight(.medium))
                            .frame(width: 80, alignment: .trailing)
                        ProgressView(value: window.usedPercent, total: 100)
                            .progressViewStyle(.linear)
                            .tint(SeldonColors.accent)
                            .frame(minWidth: 160, maxWidth: .infinity)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: SeldonSpacing.xxs) {
                            Text(UsageFormatters.localDateTime(for: window.resetsAt))
                            if UsageFormatters.shouldShowDuration(for: window.name) {
                                Text(UsageFormatters.duration(window.windowSeconds))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 136, alignment: .leading)
                        .accessibilityLabel("Resets \(UsageFormatters.fullLocalDateTime(window.resetsAt))")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(sample.label), \(window.name), \(UsageFormatters.percent(window.usedPercent)) used, resets \(UsageFormatters.fullLocalDateTime(window.resetsAt))")
                }
                Text("\(UsageFormatters.observedText(for: sample.observedAt)) · \(UsageFormatters.sampleAge(sample.ageSeconds))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if sample.hasDiagnostics {
                    Text("Service reported an issue")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Account unavailable")
                    .font(.body)
                    .foregroundStyle(.secondary)
                if let accountForecast = forecast?.accounts.first(where: { $0.accountID == result.accountID }) {
                    AccountRunwaySummary(account: accountForecast, allowsEstimate: false)
                }
            }
        }
        .padding(.vertical, SeldonSpacing.sm)
        .overlay(alignment: .bottom) {
            Divider().foregroundStyle(SeldonColors.separator).accessibilityHidden(true)
        }
    }
}
