import SwiftUI

#if os(visionOS)
@main
struct SeldonVisionApp: App {
    @State private var model: DashboardModel

    init() {
        _model = State(initialValue: DashboardModel(service: URLSessionUsageService(), connectionStore: UserDefaultsConnectionStore()))
    }

    var body: some Scene {
        WindowGroup {
            DashboardView(model: model)
                .frame(minWidth: 420, minHeight: 420)
        }
        .defaultSize(width: 1_160, height: 760)
        .windowResizability(.contentMinSize)
    }
}
#endif
