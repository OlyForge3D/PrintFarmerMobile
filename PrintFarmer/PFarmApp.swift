import SwiftUI

@main
struct PFarmApp: App {
    @State private var router = AppRouter()
    @State private var authViewModel: AuthViewModel
    @State private var services: ServiceContainer
    @State private var themeManager = ThemeManager()

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
            .environment(themeManager)
            .tint(Color.pfAccent)
            .preferredColorScheme(themeManager.preferredColorScheme)
            .task {
                await authViewModel.restoreSession()
            }
        }
    }
}
