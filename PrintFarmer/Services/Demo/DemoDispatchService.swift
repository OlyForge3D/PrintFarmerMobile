import Foundation

// MARK: - Demo Dispatch Service

final class DemoDispatchService: DispatchServiceProtocol, @unchecked Sendable {

    func getQueueStatus() async throws -> DispatchQueueStatus {
        DispatchQueueStatus(
            pendingUnassignedJobs: 2,
            totalQueuedJobs: 6,
            idlePrinters: 1,
            busyPrinters: 4,
            printerQueueDepths: [
                PrinterQueueDepth(printerId: DemoData.prusaMK4_1_ID, printerName: "Prusa MK4 #1",
                                  queueDepth: 2, isPrinting: true, isAvailable: false),
                PrinterQueueDepth(printerId: DemoData.prusaMK4_2_ID, printerName: "Prusa MK4 #2",
                                  queueDepth: 0, isPrinting: false, isAvailable: true),
                PrinterQueueDepth(printerId: DemoData.bambuX1C_ID, printerName: "Bambu X1C",
                                  queueDepth: 1, isPrinting: true, isAvailable: false),
                PrinterQueueDepth(printerId: DemoData.bambuP1S_ID, printerName: "Bambu P1S",
                                  queueDepth: 1, isPrinting: false, isAvailable: false),
                PrinterQueueDepth(printerId: DemoData.voron24_ID, printerName: "Voron 2.4",
                                  queueDepth: 0, isPrinting: false, isAvailable: false),
                PrinterQueueDepth(printerId: DemoData.ender3V3_ID, printerName: "Ender 3 V3",
                                  queueDepth: 0, isPrinting: false, isAvailable: false),
            ],
            stats: DispatchStats(
                dispatchesLast24Hours: 8,
                averageScoreLast24Hours: 87.5,
                autoDispatchesLast24Hours: 5,
                failedDispatchesLast24Hours: 1))
    }

    func getHistory(page: Int?, pageSize: Int?) async throws -> DispatchHistoryPage {
        let now = Date()
        let entries = (0..<20).map { i in
            DispatchHistoryEntry(
                id: UUID(),
                printJobId: UUID(),
                jobName: ["benchy.gcode", "phone_case.gcode", "bracket.gcode", "gear.gcode", "lid.gcode"][i % 5],
                printerId: [DemoData.prusaMK4_1_ID, DemoData.prusaMK4_2_ID, DemoData.bambuX1C_ID,
                            DemoData.bambuP1S_ID, DemoData.voron24_ID][i % 5],
                printerName: ["Prusa MK4 #1", "Prusa MK4 #2", "Bambu X1C", "Bambu P1S", "Voron 2.4"][i % 5],
                action: i % 4 == 3 ? "Failed" : "Dispatched",
                score: Double.random(in: 70...98),
                reason: i % 4 == 3 ? "Printer offline" : "Best match by material and queue depth",
                createdAtUtc: now.addingTimeInterval(Double(-3600 * (i + 1))))
        }
        return DispatchHistoryPage(items: entries, totalCount: 48, page: page ?? 1, pageSize: pageSize ?? 20)
    }
}
