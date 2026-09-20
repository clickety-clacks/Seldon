import SwiftUI

struct SourceStatusBadge: View {
    let status: SourceStatus

    private var symbol: String {
        switch status {
        case .live: "checkmark.circle"
        case .cache: "archivebox"
        case .stale: "clock"
        case .error: "exclamationmark.circle"
        }
    }

    var body: some View {
        Label(status.displayName, systemImage: symbol)
            .foregroundStyle((status == .stale || status == .error) ? SeldonColors.attention : .secondary)
            .font(.subheadline)
            .accessibilityLabel("Source status, \(status.displayName)")
    }
}
