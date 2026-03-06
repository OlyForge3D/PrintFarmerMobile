import Foundation

@MainActor @Observable
final class NotificationsViewModel {
    var notifications: [AppNotification] = []
    var unreadCount: Int = 0
    var isLoading = false
    var errorMessage: String?

    private var notificationService: (any NotificationServiceProtocol)?

    func configure(notificationService: any NotificationServiceProtocol) {
        self.notificationService = notificationService
    }

    func loadNotifications() async {
        guard let notificationService else { return }
        isLoading = true
        errorMessage = nil

        do {
            async let notificationsTask = notificationService.listNotifications()
            async let countTask = notificationService.getUnreadCount()
            notifications = try await notificationsTask
            unreadCount = try await countTask
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func markRead(id: String) async {
        guard let notificationService else { return }
        do {
            try await notificationService.markRead(id: id)
            await loadNotifications()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllRead() async {
        guard let notificationService else { return }
        do {
            let unreadIds = notifications.filter { !$0.isRead }.map(\.id)
            guard !unreadIds.isEmpty else { return }
            try await notificationService.markAllRead(ids: unreadIds)
            await loadNotifications()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteNotification(id: String) async {
        guard let notificationService else { return }
        do {
            let wasUnread = notifications.first(where: { $0.id == id })?.isRead == false
            try await notificationService.delete(id: id)
            notifications.removeAll { $0.id == id }
            if wasUnread {
                unreadCount = max(0, unreadCount - 1)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
