import SwiftUI

#if os(iOS)
@main
struct SeldonApp: App {
    @State private var model: DashboardModel

    init() {
        _model = State(initialValue: DashboardModel(service: URLSessionUsageService(), connectionStore: UserDefaultsConnectionStore()))
    }

    var body: some Scene {
        WindowGroup {
            DashboardView(model: model)
        }
    }
}
#endif
