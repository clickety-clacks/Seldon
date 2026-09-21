import SwiftUI

struct UsageComparison: View {
    let results: [UsageResult]
    let forecast: UsageForecastSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: SeldonSpacing.md) {
                Text("Account").frame(width: 190, alignment: .leading)
                Text("Current usage").frame(maxWidth: .infinity, alignment: .leading)
                Text("Estimated runway").frame(width: 200, alignment: .trailing)
                Text("Reset").frame(width: 156, alignment: .leading)
                Color.clear.frame(width: SeldonControls.minimumTarget, height: 1)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, SeldonSpacing.sm)
            .padding(.bottom, SeldonSpacing.xs)
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                ForEach(results) { result in
                    ComparisonAccountRow(result: result, forecast: forecast?.accounts.first(where: { $0.accountID == result.accountID }))
                    if result.id != results.last?.id {
                        Divider().padding(.horizontal, SeldonSpacing.sm)
                    }
                }
            }
            .seldonGroupBackground(cornerRadius: 14)
        }
    }
}

private struct ComparisonAccountRow: View {
    @State private var isExpanded = false
    let result: UsageResult
    let forecast: UsageForecastAccount?

    var body: some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
            HStack(alignment: .center, spacing: SeldonSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    AccountIdentity(result: result)
                    SourceStatusBadge(status: result.status)
                    if result.sample?.hasDiagnostics == true {
                        Text("Service issue").font(.caption).foregroundStyle(SeldonColors.attention)
                    }
                }
                .frame(width: 190, alignment: .leading)

                VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
                    if let sample = result.sample {
                        ForEach(sample.windows) { window in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(window.name).font(.subheadline).foregroundStyle(.secondary)
                                    Spacer(minLength: 0)
                                    Text(UsageFormatters.percent(window.usedPercent))
                                        .font(.body.monospacedDigit().weight(.semibold))
                                }
                                ProgressView(value: window.usedPercent, total: 100)
                                    .tint(SeldonColors.accent)
                                    .accessibilityHidden(true)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(window.name), \(UsageFormatters.percent(window.usedPercent)) used")
                        }
                    } else {
                        Text("Usage unavailable").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    if let forecast {
                        AccountRunwaySummary(account: forecast, allowsEstimate: result.sample != nil && result.status != .error)
                    } else {
                        Text("No runway estimate").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 200, alignment: .trailing)

                VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
                    if let sample = result.sample {
                        ForEach(sample.windows) { window in
                            VStack(alignment: .leading, spacing: 4) {
                                if sample.windows.count > 1 {
                                    Text(window.name).font(.caption).foregroundStyle(.secondary)
                                }
                                Text(UsageFormatters.localDateTime(for: window.resetsAt))
                                    .font(.subheadline)
                            }
                            .accessibilityLabel("\(window.name) resets \(UsageFormatters.fullLocalDateTime(window.resetsAt))")
                        }
                    }
                }
                .frame(width: 156, alignment: .leading)

                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: SeldonControls.minimumTarget, height: SeldonControls.minimumTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Details for \(result.sample?.label ?? "unavailable account")")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            }
            if isExpanded {
                AccountUsageDetails(result: result, forecast: forecast)
            }
        }
        .padding(SeldonSpacing.sm)
        .accessibilityElement(children: .contain)
    }
}
