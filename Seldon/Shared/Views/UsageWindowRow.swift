import SwiftUI

struct UsageWindowRow: View {
    let accountLabel: String
    let window: UsageWindow
    let spacious: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SeldonSpacing.sm) {
                Text(window.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(UsageFormatters.percent(window.usedPercent) + " used")
                    .font(.title3.monospacedDigit().weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
            }

            ProgressView(value: window.usedPercent, total: 100)
                .progressViewStyle(.linear)
                .tint(SeldonColors.accent)
                .scaleEffect(x: 1, y: spacious ? 1.25 : 1, anchor: .center)
                .background(SeldonColors.surfaceRaised, in: Capsule())
                .clipShape(Capsule())
                .accessibilityHidden(true)

            Text(UsageFormatters.resetText(for: window.resetsAt))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .accessibilityHidden(true)
            if UsageFormatters.shouldShowDuration(for: window.name) {
                Text(UsageFormatters.duration(window.windowSeconds))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accountLabel), \(window.name), \(UsageFormatters.percent(window.usedPercent)) used, resets \(UsageFormatters.fullLocalDateTime(window.resetsAt))")
    }
}
