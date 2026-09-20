import SwiftUI

struct DashboardToolbar: View {
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onConnection: () -> Void

    var body: some View {
        HStack(spacing: SeldonSpacing.sm) {
            Text("SELDON")
                .font(.title2.weight(.medium))
                .tracking(2)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: SeldonSpacing.sm)
            Button(action: onRefresh) {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            #if os(visionOS)
            .frame(minWidth: 60, minHeight: 60)
            #endif
            .disabled(isRefreshing)
            .accessibilityLabel(isRefreshing ? "Refreshing usage" : "Refresh")
            Button(action: onConnection) {
                Label("Connection", systemImage: "network")
            }
            #if os(visionOS)
            .frame(minWidth: 60, minHeight: 60)
            #endif
            .accessibilityLabel("Connection")
        }
        .frame(minHeight: 44)
    }
}
