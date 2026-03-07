import SwiftUI

struct ContentView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                .tag(AppTab.dashboard)

            PrinterListView()
                .tabItem { Label("Printers", systemImage: "printer") }
                .tag(AppTab.printers)

            JobListView()
                .tabItem { Label("Jobs", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.jobs)

            SpoolInventoryView()
                .tabItem { Label("Inventory", systemImage: "cylinder.fill") }
                .tag(AppTab.inventory)

            NotificationsView()
                .tabItem { Label("Alerts", systemImage: "bell") }
                .tag(AppTab.notifications)
                .badge(router.notificationBadgeCount)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppTab.settings)
        }
    }
}
