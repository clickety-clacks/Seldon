import SwiftUI

struct ConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isServerFieldFocused: Bool
    @State private var draftURL: String
    @State private var showInvalidURL = false

    let model: DashboardModel

    init(model: DashboardModel) {
        self.model = model
        _draftURL = State(initialValue: model.savedBaseURL?.absoluteString ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Server URL", text: $draftURL, prompt: Text("https://usage.example.com"))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($isServerFieldFocused)
                        .textContentType(.URL)
                        .onChange(of: draftURL) { _, _ in showInvalidURL = false }
                } footer: {
                    VStack(alignment: .leading, spacing: SeldonSpacing.sm) {
                        Text("Enter the reachable HTTP or HTTPS address for your usage server.")
                        Text("The server must be reachable from this device. “localhost” refers to this device.")
                        if showInvalidURL {
                            Text("Enter an HTTP or HTTPS server URL.")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Connect") { save() }
                        .disabled(ConnectionURL.parse(draftURL) == nil || model.isLoading)
                }
            }
        }
        #if os(iOS)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    private func save() {
        guard let url = ConnectionURL.parse(draftURL) else {
            showInvalidURL = true
            return
        }
        Task {
            await model.connect(to: url)
            dismiss()
        }
    }
}
