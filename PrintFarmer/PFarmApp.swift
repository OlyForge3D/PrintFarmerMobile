import SwiftUI

@main
struct PFarmApp: App {
    @State private var router = AppRouter()
    @State private var authViewModel = AuthViewModel()

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
