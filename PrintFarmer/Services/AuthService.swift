import Foundation
import KeychainSwift

// MARK: - Auth Service

actor AuthService {
    private let apiClient: APIClient
    private let keychain = KeychainSwift()

    private static let tokenKey = "pf_jwt_token"
    private static let tokenExpiryKey = "pf_token_expiry"

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Authenticate against a Printfarmer server.
    /// Sets the API client's base URL and stores the JWT on success.
    func login(serverURL: String, username: String, password: String) async throws -> AuthResponse {
        // Normalize and persist the server URL
        let normalizedURL = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL
        guard let url = URL(string: normalizedURL) else {
            throw NetworkError.invalidURL(serverURL)
        }
        await apiClient.updateBaseURL(url)

        let request = LoginRequest(
            usernameOrEmail: username,
            password: password,
            rememberMe: true
        )
        let response: AuthResponse = try await apiClient.post("/api/auth/login", body: request)

        guard response.success, let token = response.token else {
            throw NetworkError.authFailed(response.error ?? "Login failed")
        }

        storeToken(token, expiresAt: response.expiresAt)
        await apiClient.setAccessToken(token)
        return response
    }

    func logout() async {
        try? await apiClient.postVoid("/api/auth/logout")
        clearCredentials()
        await apiClient.setAccessToken(nil)
    }

    /// Attempt to restore a previous session from Keychain.
    /// Returns the current user on success, nil if no valid session.
    func restoreSession() async -> UserDTO? {
        guard let token = keychain.get(Self.tokenKey) else { return nil }

        // Check if we have a saved server URL to reconnect to
        if let savedURL = APIClient.savedBaseURL() {
            await apiClient.updateBaseURL(savedURL)
        }

        await apiClient.setAccessToken(token)

        // Validate token by fetching current user
        do {
            let user: UserDTO = try await apiClient.get("/api/auth/me")
            return user
        } catch {
            clearCredentials()
            await apiClient.setAccessToken(nil)
            return nil
        }
    }

    func currentUser() async throws -> UserDTO {
        try await apiClient.get("/api/auth/me")
    }

    var isAuthenticated: Bool {
        keychain.get(Self.tokenKey) != nil
    }

    // MARK: - Token Storage

    private func storeToken(_ token: String, expiresAt: Date?) {
        keychain.set(token, forKey: Self.tokenKey)
        if let expiresAt {
            keychain.set(
                String(expiresAt.timeIntervalSince1970),
                forKey: Self.tokenExpiryKey
            )
        }
    }

    private func clearCredentials() {
        keychain.delete(Self.tokenKey)
        keychain.delete(Self.tokenExpiryKey)
    }
}
