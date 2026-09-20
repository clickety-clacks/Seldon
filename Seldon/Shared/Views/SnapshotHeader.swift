import SwiftUI

struct SnapshotHeader: View {
    let snapshot: UsageSnapshot
    let spacious: Bool
    let isShortHeight: Bool

    private var summary: String {
        snapshot.counts.nonZeroSummary.map { "\($0.0.displayName) \($0.1)" }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.xs) {
            if spacious && !isShortHeight {
                Text("Usage")
                    .font(.largeTitle.bold())
            }
            HStack(alignment: .firstTextBaseline, spacing: SeldonSpacing.sm) {
                Text("\(snapshot.results.count) \(snapshot.results.count == 1 ? "account" : "accounts")")
                    .font(.title.monospacedDigit())
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }
            Text(UsageFormatters.snapshotText(for: snapshot.generatedAt))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
