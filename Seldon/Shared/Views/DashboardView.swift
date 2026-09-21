import SwiftUI

struct DashboardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isConnectionPresented = false

    let model: DashboardModel

    var body: some View {
        platformContainer
            .task { await model.loadIfNeeded() }
            .sheet(isPresented: $isConnectionPresented) {
                ConnectionView(model: model)
            }
    }

    @ViewBuilder
    private var platformContainer: some View {
        #if os(iOS)
        NavigationStack {
            content
                .navigationTitle("Seldon")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button(action: refresh) {
                            if model.isRefreshing || model.isForecastLoading {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                        }
                        .disabled(model.isRefreshing || model.isForecastLoading || !model.hasConnection)
                        .accessibilityLabel(model.isRefreshing || model.isForecastLoading ? "Refreshing usage" : "Refresh")
                        Button(action: { isConnectionPresented = true }) {
                            Label("Connection", systemImage: "network")
                        }
                    }
                }
        }
        #else
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                DashboardToolbar(isBusy: model.isRefreshing || model.isForecastLoading, onRefresh: refresh, onConnection: { isConnectionPresented = true })
                }
            }
        #endif
    }

    private var content: some View {
        GeometryReader { proxy in
            let composition = DashboardComposition.forWidth(proxy.size.width, accessibilitySize: dynamicTypeSize.isAccessibilitySize)
            ScrollView {
                VStack(alignment: .leading, spacing: SeldonSpacing.lg) {
                    if model.hasConnection {
                        if model.isLoading && model.snapshot == nil {
                            loadingState
                        } else if model.snapshot == nil && model.initialLoadFailed {
                            initialErrorState
                        } else if let snapshot = model.snapshot {
                            dashboard(snapshot: snapshot, composition: composition, width: proxy.size.width, height: proxy.size.height)
                        }
                    } else {
                        connectionState
                    }
                }
                .frame(maxWidth: 1_560)
                .frame(maxWidth: .infinity)
                .padding(composition == .compact ? SeldonSpacing.md : SeldonSpacing.lg)
            }
            .scrollIndicators(.visible)
            .background(SeldonColors.canvas)
        }
        .frame(minWidth: 0, minHeight: 0)
    }

    @ViewBuilder
    private func dashboard(snapshot: UsageSnapshot, composition: DashboardComposition, width: CGFloat, height: CGFloat) -> some View {
        SnapshotHeader(snapshot: snapshot, spacious: composition != .compact, isShortHeight: height < 560)
        if model.refreshFailed {
            HStack(spacing: SeldonSpacing.sm) {
                Image(systemName: "exclamationmark.circle")
                Text("Refresh failed · Previous snapshot")
                Spacer()
                Button("Refresh", action: refresh)
                    .disabled(model.isRefreshing)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(SeldonSpacing.sm)
            .background(SeldonColors.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }

        if snapshot.results.isEmpty {
            ContentUnavailableView("No accounts reported", systemImage: "person.2", description: Text("This usage snapshot contains no accounts."))
        } else {
            if let forecast = model.forecast {
                UsageRunway(forecast: forecast, spacious: composition != .compact)
            } else {
                UsageRunwayUnavailable(isLoading: model.isForecastLoading)
            }

            switch composition {
            case .compact:
                cards(snapshot.results, spacious: false, forecast: model.forecast)
            case .spaciousCards:
                cards(snapshot.results, spacious: true, forecast: model.forecast)
            case .comparison:
                comparison(snapshot.results, width: width, forecast: model.forecast)
            }
        }
    }

    private func cards(_ results: [UsageResult], spacious: Bool, forecast: UsageForecastSnapshot?) -> some View {
        let columns = spacious ? [GridItem(.flexible(minimum: 300)), GridItem(.flexible(minimum: 300))] : [GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: SeldonSpacing.md) {
            ForEach(results) { result in
                AccountUsageCard(result: result, spacious: spacious, forecast: forecast?.accounts.first(where: { $0.accountID == result.accountID }))
            }
        }
    }

    private func comparison(_ results: [UsageResult], width: CGFloat, forecast: UsageForecastSnapshot?) -> some View {
        let sideBySide = width >= 1_200
        return Group {
            if sideBySide {
                HStack(alignment: .top, spacing: SeldonSpacing.lg) {
                    UsageComparison(results: results, forecast: forecast)
                    ResetAgenda(results: results)
                        .frame(width: 280)
                }
            } else {
                VStack(alignment: .leading, spacing: SeldonSpacing.lg) {
                    UsageComparison(results: results, forecast: forecast)
                    ResetAgenda(results: results)
                }
            }
        }
    }

    private var connectionState: some View {
        ContentUnavailableView {
            Label("Connect to usage server", systemImage: "network")
        } description: {
            Text("View account usage from your configured server.")
        } actions: {
            Button("Configure Connection", action: { isConnectionPresented = true })
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var loadingState: some View {
        VStack(spacing: SeldonSpacing.md) {
            ProgressView("Loading usage")
                .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var initialErrorState: some View {
        ContentUnavailableView {
            Label("Couldn't load usage", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Check the server URL, then refresh.")
        } actions: {
            HStack {
                Button("Refresh", action: refresh)
                    .buttonStyle(.borderedProminent)
                Button("Connection", action: { isConnectionPresented = true })
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func refresh() {
        Task { await model.refresh() }
    }
}
