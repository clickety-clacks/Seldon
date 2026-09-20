import SwiftUI

struct ResetAgenda: View {
    struct Entry: Identifiable {
        let id: String
        let label: String
        let windowName: String
        let date: Date
    }

    let results: [UsageResult]

    private var entries: [Entry] {
        results.flatMap { result -> [Entry] in
            guard let sample = result.sample else { return [] }
            return sample.windows.map { window in
                Entry(id: "\(result.accountID)-\(window.id)", label: sample.label, windowName: window.name, date: window.resetsAt)
            }
        }
        .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SeldonSpacing.md) {
            Text("Reported resets")
                .font(.title3.weight(.semibold))
            if entries.isEmpty {
                Text("No reported reset times")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: SeldonSpacing.xxs) {
                        Text(UsageFormatters.agendaResetText(for: entry.date))
                            .font(.body)
                        Text("\(entry.label) · \(entry.windowName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text("Times reported by Lachesis")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SeldonSpacing.md)
        .seldonGroupBackground()
    }
}
