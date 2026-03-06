import Foundation

/// Dependency container providing access to all services.
/// Created once at app startup and passed via SwiftUI environment.
@Observable
final class ServiceContainer: @unchecked Sendable {
    let apiClient: APIClient
    let authService: AuthService
    let printerService: PrinterService
    let jobService: JobService
    let locationService: LocationService
    let signalRService: SignalRService

    init(baseURL: URL? = nil) {
        let resolvedURL = baseURL
            ?? APIClient.savedBaseURL()
            ?? AppConfig.baseURL
        self.apiClient = APIClient(baseURL: resolvedURL)
        self.authService = AuthService(apiClient: apiClient)
        self.printerService = PrinterService(apiClient: apiClient)
        self.jobService = JobService(apiClient: apiClient)
        self.locationService = LocationService(apiClient: apiClient)
        self.signalRService = SignalRService(serverURL: resolvedURL) {
            nil
        }
    }
}
