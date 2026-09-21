import SwiftUI

struct UsageWindowRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let accountLabel: String
    let window: UsageWindow
    let spacious: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) { name; percentage }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: SeldonSpacing.xs) {
                    name
                    Spacer(minLength: 0)
                    percentage
                }
            }
            ProgressView(value: window.usedPercent, total: 100)
                .progressViewStyle(.linear)
                .tint(SeldonColors.accent)
                .accessibilityHidden(true)
            Text(UsageFormatters.resetText(for: window.resetsAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accountLabel), \(window.name), \(UsageFormatters.percent(window.usedPercent)) used, resets \(UsageFormatters.fullLocalDateTime(window.resetsAt))")
    }

    private var name: some View {
        Text(window.name).font(.subheadline).foregroundStyle(.secondary)
    }

    private var percentage: some View {
        Text(UsageFormatters.percent(window.usedPercent) + " used")
            .font(.subheadline.monospacedDigit().weight(.semibold))
            .foregroundStyle(.primary)
    }
}
