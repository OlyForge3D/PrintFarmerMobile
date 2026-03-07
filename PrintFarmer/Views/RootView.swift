import SwiftUI

/// Root view that gates between loading, login, and main content.
///
/// Extracted from `PFarmApp` so that `@Observable` property tracking
/// on `AuthViewModel` runs inside a real `View` body — this ensures
/// SwiftUI reliably re-renders when `isAuthenticated` changes.
struct RootView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                ContentView()
            } else if !authViewModel.hasCheckedAuth {
                launchScreen
            } else {
                LoginView()
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
