import SwiftUI

@main
struct PFarmApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
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
            RootView()
                .environment(router)
                .environment(authViewModel)
                .environment(services)
                .environment(themeManager)
                .tint(Color.pfAccent)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .task {
                    await authViewModel.restoreSession()
                    #if canImport(UIKit)
                    PushNotificationManager.shared.configure(notificationService: services.notificationService)
                    await PushNotificationManager.shared.refreshPermissionStatus()
                    if PushNotificationManager.shared.pushEnabled {
                        await PushNotificationManager.shared.requestPermissionAndRegister()
                    }
                    #endif
                }
        }
    }
}
