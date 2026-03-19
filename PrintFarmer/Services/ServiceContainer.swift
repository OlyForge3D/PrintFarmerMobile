import Foundation

/// Dependency container providing access to all services.
/// Created once at app startup and passed via SwiftUI environment.
@Observable
final class ServiceContainer: @unchecked Sendable {
    let apiClient: APIClient?
    let authService: any AuthServiceProtocol
    let printerService: any PrinterServiceProtocol
    let jobService: any JobServiceProtocol
    let locationService: any LocationServiceProtocol
    let statisticsService: any StatisticsServiceProtocol
    let notificationService: any NotificationServiceProtocol
    let signalRService: any SignalRServiceProtocol
    let spoolService: any SpoolServiceProtocol
    let maintenanceService: any MaintenanceServiceProtocol
    let autoPrintService: any AutoDispatchServiceProtocol
    let jobAnalyticsService: any JobAnalyticsServiceProtocol
    let predictiveService: any PredictiveServiceProtocol
    let dispatchService: any DispatchServiceProtocol
    #if canImport(UIKit)
    let qrScannerService: QRSpoolScannerService?
    let nfcService: NFCService?
    #endif

    init(baseURL: URL? = nil) {
        let resolvedURL = baseURL
            ?? APIClient.savedBaseURL()
            ?? AppConfig.baseURL
        let client = APIClient(baseURL: resolvedURL)
        self.apiClient = client
        self.authService = AuthService(apiClient: client)
        self.printerService = PrinterService(apiClient: client)
        self.jobService = JobService(apiClient: client)
        self.locationService = LocationService(apiClient: client)
        self.statisticsService = StatisticsService(apiClient: client)
        self.notificationService = NotificationService(apiClient: client)
        self.spoolService = SpoolService(apiClient: client)
        self.maintenanceService = MaintenanceService(apiClient: client)
        self.autoPrintService = AutoDispatchService(apiClient: client)
        self.jobAnalyticsService = JobAnalyticsService(apiClient: client)
        self.predictiveService = PredictiveService(apiClient: client)
        self.dispatchService = DispatchService(apiClient: client)
        #if canImport(UIKit)
        self.qrScannerService = QRSpoolScannerService()
        self.nfcService = NFCService()
        #endif

        self.signalRService = SignalRService(serverURL: resolvedURL) {
            await client.currentAccessToken()
        }
    }

    /// Creates a ServiceContainer wired with demo (mock) services.
    static func demo() -> ServiceContainer {
        return ServiceContainer(
            authService: DemoAuthService(),
            printerService: DemoPrinterService(),
            jobService: DemoJobService(),
            locationService: DemoLocationService(),
            statisticsService: DemoStatisticsService(),
            notificationService: DemoNotificationService(),
            signalRService: DemoSignalRService(),
            spoolService: DemoSpoolService(),
            maintenanceService: DemoMaintenanceService(),
            autoPrintService: DemoAutoDispatchService(),
            jobAnalyticsService: DemoJobAnalyticsService(),
            predictiveService: DemoPredictiveService(),
            dispatchService: DemoDispatchService()
        )
    }

    /// Internal initializer used by the `demo()` factory.
    private init(
        authService: any AuthServiceProtocol,
        printerService: any PrinterServiceProtocol,
        jobService: any JobServiceProtocol,
        locationService: any LocationServiceProtocol,
        statisticsService: any StatisticsServiceProtocol,
        notificationService: any NotificationServiceProtocol,
        signalRService: any SignalRServiceProtocol,
        spoolService: any SpoolServiceProtocol,
        maintenanceService: any MaintenanceServiceProtocol,
        autoPrintService: any AutoDispatchServiceProtocol,
        jobAnalyticsService: any JobAnalyticsServiceProtocol,
        predictiveService: any PredictiveServiceProtocol,
        dispatchService: any DispatchServiceProtocol
    ) {
        self.apiClient = nil
        self.authService = authService
        self.printerService = printerService
        self.jobService = jobService
        self.locationService = locationService
        self.statisticsService = statisticsService
        self.notificationService = notificationService
        self.signalRService = signalRService
        self.spoolService = spoolService
        self.maintenanceService = maintenanceService
        self.autoPrintService = autoPrintService
        self.jobAnalyticsService = jobAnalyticsService
        self.predictiveService = predictiveService
        self.dispatchService = dispatchService
        #if canImport(UIKit)
        self.qrScannerService = nil
        self.nfcService = nil
        #endif
    }
}
