import SwiftUI

@MainActor @Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard
    var dashboardPath = NavigationPath()
    var printersPath = NavigationPath()
    var jobsPath = NavigationPath()
    var notificationsPath = NavigationPath()
    var notificationBadgeCount: Int = 0

    func resetToRoot(tab: AppTab) {
        switch tab {
        case .dashboard: dashboardPath = NavigationPath()
        case .printers: printersPath = NavigationPath()
        case .jobs: jobsPath = NavigationPath()
        case .notifications: notificationsPath = NavigationPath()
        case .settings: break
        }
    }
}

enum AppTab: Hashable {
    case dashboard
    case printers
    case jobs
    case notifications
    case settings
}
