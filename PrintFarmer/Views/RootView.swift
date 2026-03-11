import SwiftUI

/// Root view that gates between loading, login, and main content.
///
/// Extracted from `PFarmApp` so that `@Observable` property tracking
/// on `AuthViewModel` runs inside a real `View` body — this ensures
/// SwiftUI reliably re-renders when `isAuthenticated` changes.
struct RootView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(AppRouter.self) private var router
    @Environment(ServiceContainer.self) private var services
    @State private var pendingReadyMonitor = PendingReadyMonitor()

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                ContentView()
                    .task {
                        pendingReadyMonitor.configure(autoPrintService: services.autoPrintService)
                        pendingReadyMonitor.startMonitoring()
                    }
                    .onChange(of: pendingReadyMonitor.pendingReadyCount) { _, newValue in
                        router.pendingReadyCount = newValue
                    }
            } else if !authViewModel.hasCheckedAuth {
                launchScreen
            } else {
                LoginView()
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                pendingReadyMonitor.stopMonitoring()
                router.pendingReadyCount = 0
            }
        }
    }

    /// Shown briefly while `restoreSession()` checks for a saved token.
    private var launchScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "printer.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.pfAccent)

            Text("PrintFarmer")
                .font(.largeTitle.bold())

            ProgressView()
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
