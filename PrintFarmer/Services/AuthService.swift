import Foundation
import KeychainSwift

// MARK: - Auth Service

actor AuthService {
    private let apiClient: APIClient
    private let keychain = KeychainSwift()

    private static let accessTokenKey = "pf_access_token"
    private static let refreshTokenKey = "pf_refresh_token"

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func login(usernameOrEmail: String, password: String, rememberMe: Bool = false) async throws -> LoginResponse {
        let request = LoginRequest(
            usernameOrEmail: usernameOrEmail,
            password: password,
            rememberMe: rememberMe
        )
        let response: LoginResponse = try await apiClient.post("/api/auth/login", body: request)
        await storeTokens(access: response.accessToken, refresh: response.refreshToken)
        await apiClient.setAccessToken(response.accessToken)
        return response
    }

    func logout() async {
        try? await apiClient.post("/api/auth/logout")
        clearTokens()
        await apiClient.setAccessToken(nil)
    }

    func restoreSession() async -> Bool {
        guard let token = keychain.get(Self.accessTokenKey) else { return false }
        await apiClient.setAccessToken(token)

        // Validate token by fetching current user
        do {
            let _: UserDTO = try await apiClient.get("/api/auth/me")
            return true
        } catch {
            clearTokens()
            await apiClient.setAccessToken(nil)
            return false
        }
    }

    func currentUser() async throws -> UserDTO {
        try await apiClient.get("/api/auth/me")
    }

    // MARK: - Token Storage

    private func storeTokens(access: String, refresh: String) async {
        keychain.set(access, forKey: Self.accessTokenKey)
        keychain.set(refresh, forKey: Self.refreshTokenKey)
    }

    private func clearTokens() {
        keychain.delete(Self.accessTokenKey)
        keychain.delete(Self.refreshTokenKey)
    }
}
