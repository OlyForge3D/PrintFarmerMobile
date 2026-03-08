import SwiftUI

@MainActor @Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard
    var dashboardPath = NavigationPath()
    var printersPath = NavigationPath()
    var jobsPath = NavigationPath()
    var notificationsPath = NavigationPath()
    var inventoryPath = NavigationPath()
    var maintenancePath = NavigationPath()
    var notificationBadgeCount: Int = 0
    var sidebarVisibility: NavigationSplitViewVisibility = .automatic
    var pendingNFCReadyPrinterId: UUID?

    func navigate(to destination: DeepLinkDestination) {
        switch destination {
        case .printerDetail(let id):
            selectedTab = .printers
            printersPath = NavigationPath()
            printersPath.append(AppDestination.printerDetail(id: id))
        case .printerReady(let id):
            selectedTab = .printers
            printersPath = NavigationPath()
            pendingNFCReadyPrinterId = id
            printersPath.append(AppDestination.printerDetail(id: id))
        }
    }

    func resetToRoot(tab: AppTab) {
        switch tab {
        case .dashboard: dashboardPath = NavigationPath()
        case .printers: printersPath = NavigationPath()
        case .jobs: jobsPath = NavigationPath()
        case .notifications: notificationsPath = NavigationPath()
        case .inventory: inventoryPath = NavigationPath()
        case .maintenance: maintenancePath = NavigationPath()
        case .settings: break
        }
    }
}

enum AppTab: Hashable {
    case dashboard
    case printers
    case jobs
    case notifications
    case inventory
    case maintenance
    case settings
}
