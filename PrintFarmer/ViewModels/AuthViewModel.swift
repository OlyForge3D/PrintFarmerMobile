import Foundation

/// App-level authentication state that controls whether the user sees
/// LoginView or the main TabView. Injected via @Environment.
@Observable
final class AuthViewModel: @unchecked Sendable {
    var isAuthenticated = false
    var currentUser: UserDTO?
    var isLoading = false
    var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: - Session Restoration

    func restoreSession() async {
        isLoading = true
        if let user = await authService.restoreSession() {
            currentUser = user
            isAuthenticated = true
        }
        isLoading = false
    }

    // MARK: - Login / Logout

    func login(serverURL: String, username: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await authService.login(
                serverURL: serverURL,
                username: username,
                password: password
            )
            currentUser = response.user
            isAuthenticated = true
        } catch let error as NetworkError {
            errorMessage = friendlyMessage(for: error)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout() async {
        await authService.logout()
        isAuthenticated = false
        currentUser = nil
    }

    // MARK: - Helpers

    private func friendlyMessage(for error: NetworkError) -> String {
        switch error {
        case .unauthorized:
            "Invalid username or password."
        case .forbidden:
            "Your account does not have access."
        case .serverError:
            "The server encountered an error. Please try again."
        case .invalidURL:
            "Could not reach the server. Check the URL."
        case .noConnection:
            "No internet connection. Check your network."
        case .serverUnreachable:
            "Could not reach the server. Check the URL and try again."
        case .authFailed(let message):
            message
        default:
            error.errorDescription ?? "An unexpected error occurred."
        }
    }
}
