import SwiftUI

@main
struct PFarmApp: App {
    @State private var router = AppRouter()
    @State private var authViewModel: AuthViewModel
    @State private var services: ServiceContainer

    init() {
        let defaultURL = APIClient.savedBaseURL() ?? AppConfig.baseURL
        let container = ServiceContainer(baseURL: defaultURL)
        _services = State(initialValue: container)
        let authService = AuthService(apiClient: container.apiClient)
        _authViewModel = State(initialValue: AuthViewModel(authService: authService))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ContentView()
                        .environment(router)
                        .environment(authViewModel)
                        .environment(services)
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
