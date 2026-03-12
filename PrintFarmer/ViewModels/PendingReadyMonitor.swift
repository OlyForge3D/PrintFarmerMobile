import Foundation
import os
#if canImport(UserNotifications)
import UserNotifications
#endif

@MainActor @Observable
final class PendingReadyMonitor {
    var pendingReadyCount: Int = 0
    private var pollingTask: Task<Void, Never>?
    private var autoPrintService: (any AutoDispatchServiceProtocol)?
    private var printerService: (any PrinterServiceProtocol)?

    /// Printer IDs for which we've already fired a local notification.
    /// Cleared when a printer leaves PendingReady so it can re-notify.
    private var notifiedPrinterIds: Set<UUID> = []

    private let logger = Logger(subsystem: "com.printfarmer.ios", category: "PendingReadyMonitor")
    private static let notificationCategory = "PENDING_READY"

    func configure(
        autoPrintService: any AutoDispatchServiceProtocol,
        printerService: any PrinterServiceProtocol
    ) {
        self.autoPrintService = autoPrintService
        self.printerService = printerService
    }

    func startMonitoring() {
        stopMonitoring()

        pollingTask = Task {
            while !Task.isCancelled {
                await updatePendingReadyCount()

                do {
                    try await Task.sleep(for: .seconds(10))
                } catch {
                    break
                }
            }
        }
    }

    func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
        notifiedPrinterIds.removeAll()
    }

    // MARK: - Notification Permission

    /// Request local notification permission. Call once at first launch.
    func requestNotificationPermission() async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            logger.info("Notification permission \(granted ? "granted" : "denied")")
        } catch {
            logger.error("Failed to request notification permission: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Polling

    private func updatePendingReadyCount() async {
        guard let autoPrintService else { return }

        do {
            let statuses = try await autoPrintService.getAllStatus()
            let pendingReadyStatuses = statuses.filter { $0.state == "PendingReady" }
            let currentPendingIds = Set(pendingReadyStatuses.map(\.printerId))

            pendingReadyCount = pendingReadyStatuses.count

            // Clear notifications for printers that left PendingReady
            notifiedPrinterIds = notifiedPrinterIds.intersection(currentPendingIds)

            // Find newly-entered PendingReady printers
            let newPrinterIds = currentPendingIds.subtracting(notifiedPrinterIds)
            if !newPrinterIds.isEmpty {
                await sendLocalNotification(for: newPrinterIds)
                notifiedPrinterIds.formUnion(newPrinterIds)
            }
        } catch {
            // Silently handle errors in background polling
        }
    }

    // MARK: - Local Notification

    private func sendLocalNotification(for printerIds: Set<UUID>) async {
        #if canImport(UserNotifications)
        let names = await resolveNames(for: printerIds)

        let content = UNMutableNotificationContent()
        content.title = "Bed Clear Required"
        if names.count == 1, let name = names.first {
            content.body = "\(name) is ready for the next job — clear the bed to continue."
        } else {
            let list = names.sorted().joined(separator: ", ")
            content.body = "\(list) need beds cleared to continue auto-dispatch."
        }
        content.sound = .default
        content.categoryIdentifier = Self.notificationCategory

        let request = UNNotificationRequest(
            identifier: "pending-ready-\(UUID().uuidString)",
            content: content,
            trigger: nil // fire immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Local notification sent for \(printerIds.count) printer(s)")
        } catch {
            logger.error("Failed to schedule local notification: \(error.localizedDescription)")
        }
        #endif
    }

    /// Resolve printer UUIDs to display names, falling back to short ID.
    private func resolveNames(for ids: Set<UUID>) async -> [String] {
        guard let printerService else {
            return ids.map { $0.uuidString.prefix(8).description }
        }

        do {
            let printers = try await printerService.list(includeDisabled: true)
            let nameMap = Dictionary(uniqueKeysWithValues: printers.map { ($0.id, $0.name) })
            return ids.map { nameMap[$0] ?? $0.uuidString.prefix(8).description }
        } catch {
            return ids.map { $0.uuidString.prefix(8).description }
        }
    }
}
