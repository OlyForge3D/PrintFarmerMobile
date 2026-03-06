import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showLogoutConfirmation = false
    @State private var showChangeURL = false
    @State private var newServerURL = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let user = authViewModel.currentUser {
                        LabeledContent("Username", value: user.username)
                        LabeledContent("Email", value: user.email)

                        if !user.roles.isEmpty {
                            LabeledContent("Roles", value: user.roles.joined(separator: ", "))
                        }
                    }

                    Button("Sign Out", role: .destructive) {
                        showLogoutConfirmation = true
                    }
                }

                Section("Server") {
                    let savedURL = UserDefaults.standard.string(forKey: APIClient.serverURLKey) ?? "Not configured"
                    LabeledContent("API URL", value: savedURL)

                    Button {
                        newServerURL = UserDefaults.standard.string(forKey: APIClient.serverURLKey) ?? ""
                        showChangeURL = true
                    } label: {
                        Label("Change Server URL", systemImage: "link")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: AppConfig.appVersion)
                    LabeledContent("Build", value: AppConfig.buildNumber)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Sign Out?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { await authViewModel.logout() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will need to sign in again to access your print farm.")
            }
            .alert("Change Server URL", isPresented: $showChangeURL) {
                TextField("https://print.example.com", text: $newServerURL)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                Button("Save") {
                    let trimmed = newServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        UserDefaults.standard.set(trimmed, forKey: APIClient.serverURLKey)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter the URL of your Printfarmer server. You will need to sign in again.")
            }
        }
    }
}
