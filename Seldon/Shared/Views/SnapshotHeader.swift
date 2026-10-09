import SwiftUI

struct SnapshotHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let snapshot: UsageSnapshot
    let spacious: Bool
    let isShortHeight: Bool

    private var summary: String {
        snapshot.counts.nonZeroSummary.map { "\($0.1) \($0.0.displayName.lowercased())" }.joined(separator: " · ")
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    title
                    Text(summary).foregroundStyle(.secondary)
                    timestamp
                }
            } else {
                summaryRow
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: SeldonSpacing.xs) {
                title
                Text(summary).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                timestamp
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: SeldonSpacing.xs) {
                    title
                    Text(summary).foregroundStyle(.secondary)
                }
                timestamp
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: some View {
        Text("\(snapshot.results.count) \(snapshot.results.count == 1 ? "account" : "accounts")")
            .font(.subheadline.weight(.semibold))
    }

    private var timestamp: some View {
        Text("Updated \(UsageFormatters.localDateTime(for: snapshot.generatedAt))")
            .foregroundStyle(.secondary)
            .accessibilityLabel(UsageFormatters.snapshotText(for: snapshot.generatedAt))
    }
}
