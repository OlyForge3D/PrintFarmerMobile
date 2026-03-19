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
    /// IP addresses default to `http://` (local/Tailscale), hostnames to `https://`.
    var normalizedServerURL: String? {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let urlString: String
        if trimmed.contains("://") {
            urlString = trimmed
        } else {
            let hostPart = trimmed.components(separatedBy: "/").first?
                .components(separatedBy: ":").first ?? trimmed
            let isIP = hostPart.range(
                of: #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#,
                options: .regularExpression
            ) != nil
            urlString = isIP ? "http://\(trimmed)" : "https://\(trimmed)"
        }
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              scheme == "http" || scheme == "https",
              let host = url.host
        else { return nil }

        // IP addresses always use http:// (local/Tailscale networks don't serve TLS)
        var result = urlString
        if scheme == "https",
           host.range(of: #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#, options: .regularExpression) != nil {
            result = "http" + result.dropFirst("https".count)
        }

        // Strip trailing slash for consistency
        return result.hasSuffix("/") ? String(result.dropLast()) : result
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
