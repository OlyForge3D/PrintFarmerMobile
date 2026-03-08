import Foundation

/// Manages login form state, validation, and server URL persistence.
@MainActor @Observable
final class LoginViewModel {
    var serverURL: String = ""
    var usernameOrEmail: String = ""
    var password: String = ""
    var isServerURLExpanded: Bool = false

    // MARK: - Validation

    var isFormValid: Bool {
        !usernameOrEmail.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && isValidServerURL
    }

    var isValidServerURL: Bool {
        normalizedServerURL != nil
    }

    var serverURLValidationError: String? {
        let trimmed = serverURL.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Server URL is required" }
        if !isValidServerURL { return "Enter a valid URL (e.g. https://print.example.com)" }
        return nil
    }

    /// Normalizes user input into a clean URL string for the API layer.
    var normalizedServerURL: String? {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let urlString = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              scheme == "http" || scheme == "https",
              url.host != nil
        else { return nil }

        // Strip trailing slash for consistency
        return urlString.hasSuffix("/") ? String(urlString.dropLast()) : urlString
    }

    // MARK: - Initialization

    init() {
        if let saved = UserDefaults.standard.string(forKey: APIClient.serverURLKey), !saved.isEmpty {
            self.serverURL = saved
            self.isServerURLExpanded = false
        } else {
            self.isServerURLExpanded = true
        }
    }

    // MARK: - Login

    func login(using authViewModel: AuthViewModel) async {
        guard let serverURL = normalizedServerURL else { return }

        await authViewModel.login(
            serverURL: serverURL,
            username: usernameOrEmail.trimmingCharacters(in: .whitespaces),
            password: password
        )
    }
}
