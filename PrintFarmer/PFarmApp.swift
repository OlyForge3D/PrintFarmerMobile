import SwiftUI

@main
struct PFarmApp: App {
    @State private var router = AppRouter()
    @State private var authViewModel: AuthViewModel

    private let apiClient: APIClient

    init() {
        let defaultURL = APIClient.savedBaseURL() ?? AppConfig.baseURL
        let client = APIClient(baseURL: defaultURL)
        self.apiClient = client
        let authService = AuthService(apiClient: client)
        _authViewModel = State(initialValue: AuthViewModel(authService: authService))
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
                await authViewModel.restoreSession()
            }
        }
    }
}
