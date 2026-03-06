import SwiftUI

@Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard
    var dashboardPath = NavigationPath()
    var printersPath = NavigationPath()
    var jobsPath = NavigationPath()
    var locationsPath = NavigationPath()

    func resetToRoot(tab: AppTab) {
        switch tab {
        case .dashboard: dashboardPath = NavigationPath()
        case .printers: printersPath = NavigationPath()
        case .jobs: jobsPath = NavigationPath()
        case .locations: locationsPath = NavigationPath()
        case .settings: break
        }
    }
}

enum AppTab: Hashable {
    case dashboard
    case printers
    case jobs
    case locations
    case settings
}
