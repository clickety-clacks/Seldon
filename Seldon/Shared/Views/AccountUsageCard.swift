import SwiftUI

struct AccountUsageCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isExpanded = false
    let result: UsageResult
    let spacious: Bool
    let forecast: UsageForecastAccount?

    var body: some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
            Button {
                isExpanded.toggle()
            } label: {
                VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
                            AccountIdentity(result: result, showsStatus: true)
                            estimate
                            disclosure
                        }
                    } else {
                        HStack(alignment: .top, spacing: SeldonSpacing.xs) {
                            AccountIdentity(result: result, showsStatus: true)
                            Spacer(minLength: 0)
                            estimate
                            disclosure
                        }
                    }
                    if let sample = result.sample {
                        ForEach(sample.windows) { window in
                            UsageWindowRow(accountLabel: sample.label, window: window, spacious: spacious)
                        }
                    }
                    if result.sample?.hasDiagnostics == true {
                        Text("Service issue")
                            .font(.caption)
                            .foregroundStyle(SeldonColors.attention)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: SeldonControls.minimumTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint("Shows account and forecast details")
            if isExpanded {
                AccountUsageDetails(result: result, forecast: forecast)
            }
        }
        .padding(SeldonSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .seldonGroupBackground(cornerRadius: 14)
        .accessibilityElement(children: .contain)
    }

    private var disclosure: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var estimate: some View {
        if let forecast {
            AccountRunwaySummary(account: forecast, allowsEstimate: result.sample != nil && result.status != .error)
        } else {
            Text(result.sample == nil ? "Account unavailable" : "No runway estimate")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct AccountIdentity: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let result: UsageResult
    var showsStatus = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.sample?.label ?? "Account unavailable")
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if dynamicTypeSize.isAccessibilitySize {
                metadata
            } else {
                HStack(spacing: 6) { metadata }
            }
        }
    }

    @ViewBuilder
    private var metadata: some View {
        if let sample = result.sample {
            Text(UsageForecastFormatters.planLine(provider: sample.provider, plan: sample.plan))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if showsStatus {
            SourceStatusBadge(status: result.status)
        }
    }
}

struct AccountUsageDetails: View {
    let result: UsageResult
    let forecast: UsageForecastAccount?

    var body: some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
            Divider()
            if let sample = result.sample {
                Text("\(UsageFormatters.observedText(for: sample.observedAt)) · \(UsageFormatters.sampleAge(sample.ageSeconds))")
                if sample.hasDiagnostics {
                    Text("The usage service reported an issue with this sample.")
                }
                ForEach(sample.windows.filter { UsageFormatters.shouldShowDuration(for: $0.name) }) { window in
                    Text("\(window.name) allowance covers \(UsageFormatters.duration(window.windowSeconds)).")
                }
            } else {
                Text("The usage service could not read this account.")
            }
            if let forecast, result.sample != nil, result.status != .error {
                if forecast.hasQualification {
                    Text("Some limits have no finite estimate. The displayed runway may not cover every limit.")
                } else if forecast.hasDiagnostics {
                    Text("The forecast has limitations in its observed usage or demand.")
                }
                if forecast.windows.contains(where: { $0.isResetBound }) {
                    Text("At least one limit resets before its projected depletion.")
                }
                Text(UsageForecastFormatters.coverage(forecast.coverageHours))
                Text("Estimate as of \(UsageFormatters.localDateTime(for: forecast.generatedAt))")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, SeldonSpacing.xs)
    }
}
