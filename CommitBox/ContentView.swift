import SwiftUI
import WidgetKit

struct ContentView: View {
    @AppStorage("username") private var username = ""
    @State private var calendar: ContributionCalendar?
    @State private var errorMessage: String?
    @State private var isLoading = false

    private let previewSize = CGSize(width: 364, height: 170)
    private let previewShape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                TextField("GitHub username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onSubmit(load)
                Button("Load", action: load)
                    .disabled(username.isEmpty || isLoading)
            }

            Group {
                if let calendar {
                    ContributionCard(calendar: calendar)
                        .padding(16)
                        .frame(width: previewSize.width, height: previewSize.height)
                        .background { ContributionGlassBackground() }
                        .containerShape(previewShape)
                        .clipShape(previewShape)
                        .environment(\.colorScheme, .dark)
                        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                } else if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 200)

            Button("Refresh Widgets") {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .frame(width: previewSize.width)
        .padding(24)
        .task { load() }
    }

    private func load() {
        guard !username.isEmpty, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                calendar = try await ContributionService.fetch(username: username)
            } catch {
                calendar = nil
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}
