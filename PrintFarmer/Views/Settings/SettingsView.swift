import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let user = authViewModel.currentUser {
                        LabeledContent("Username", value: user.username)
                        LabeledContent("Email", value: user.email)
                    }

                    Button("Sign Out", role: .destructive) {
                        Task {
                            await authViewModel.logout()
                        }
                    }
                }

                Section("Server") {
                    LabeledContent("API URL", value: AppConfig.baseURL.absoluteString)
                }

                Section("About") {
                    LabeledContent("Version", value: AppConfig.appVersion)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
