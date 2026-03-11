import Foundation

@MainActor @Observable
final class PendingReadyMonitor {
    var pendingReadyCount: Int = 0
    private var pollingTask: Task<Void, Never>?
    private var autoPrintService: (any AutoDispatchServiceProtocol)?
    
    func configure(autoPrintService: any AutoDispatchServiceProtocol) {
        self.autoPrintService = autoPrintService
    }
    
    func startMonitoring() {
        stopMonitoring()
        
        pollingTask = Task {
            while !Task.isCancelled {
                await updatePendingReadyCount()
                
                // Wait 10 seconds before next poll
                do {
                    try await Task.sleep(for: .seconds(10))
                } catch {
                    // Task was cancelled, exit gracefully
                    break
                }
            }
        }
    }
    
    func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    private func updatePendingReadyCount() async {
        guard let autoPrintService else { return }
        
        do {
            let statuses = try await autoPrintService.getAllStatus()
            let count = statuses.filter { $0.state == "PendingReady" }.count
            pendingReadyCount = count
        } catch {
            // Silently handle errors in background polling
            // Don't show alerts or update count on error
        }
    }
}
