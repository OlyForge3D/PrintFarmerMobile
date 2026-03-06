import SwiftUI

@main
struct PFarmApp: App {
    @State private var router = AppRouter()
    @State private var authViewModel = AuthViewModel()

    private let apiClient: APIClient
    private let authService: AuthService

    init() {
        let defaultURL = APIClient.savedBaseURL() ?? AppConfig.baseURL
        self.apiClient = APIClient(baseURL: defaultURL)
        self.authService = AuthService(apiClient: apiClient)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ContentView()
                        .environment(router)
                        .environment(authViewModel)
                } else {
                    LoginView()
                        .environment(authViewModel)
                }
            }
            .task {
                authViewModel.configure(with: authService)
                await authViewModel.restoreSession()
            }
        }
    }
}
