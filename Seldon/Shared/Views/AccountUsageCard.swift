import SwiftUI

struct AccountUsageCard: View {
    let result: UsageResult
    let spacious: Bool
    let forecast: UsageForecastAccount? = nil

    private var sample: UsageSample? { result.sample }

    var body: some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.md) {
            header
            if let sample {
                if let forecast, result.status != .error {
                    AccountRunwaySummary(account: forecast)
                }
                VStack(alignment: .leading, spacing: SeldonSpacing.md) {
                    ForEach(sample.windows) { window in
                        UsageWindowRow(accountLabel: displayLabel(for: sample), window: window, spacious: spacious)
                    }
                }
                footer(sample)
            } else {
                Text("Account unavailable")
                    .font(.body)
                    .foregroundStyle(.secondary)
                if let forecast {
                    AccountRunwaySummary(account: forecast, allowsEstimate: false)
                }
            }
        }
        .padding(spacious ? 20 : SeldonSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .seldonGroupBackground()
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: SeldonSpacing.sm) {
                titleBlock
                Spacer(minLength: SeldonSpacing.sm)
                SourceStatusBadge(status: result.status)
            }
            VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
                titleBlock
                SourceStatusBadge(status: result.status)
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.xxs) {
            Text(sample?.label ?? "Account unavailable")
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(nil)
            if let sample {
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
    }

    @ViewBuilder
    private func footer(_ sample: UsageSample) -> some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
            Divider()
                .foregroundStyle(SeldonColors.separator)
                .accessibilityHidden(true)
            Text("\(UsageFormatters.observedText(for: sample.observedAt)) · \(UsageFormatters.sampleAge(sample.ageSeconds))")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if sample.hasDiagnostics {
                Text("Service reported an issue")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func displayLabel(for sample: UsageSample) -> String {
        sample.label.isEmpty ? "Account" : sample.label
    }
}
