import Foundation

@Observable
final class AuthViewModel: @unchecked Sendable {
    var isAuthenticated = false
    var currentUser: UserDTO?
    var isLoading = false
    var errorMessage: String?

    private var authService: AuthService?

    func configure(with service: AuthService) {
        self.authService = service
    }

    func restoreSession() async {
        // Session restoration will be wired when ServiceContainer is integrated
    }

    func login(usernameOrEmail: String, password: String) async {
        guard let authService else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await authService.login(
                usernameOrEmail: usernameOrEmail,
                password: password
            )
            currentUser = response.user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout() async {
        guard let authService else { return }
        await authService.logout()
        isAuthenticated = false
        currentUser = nil
    }
}
