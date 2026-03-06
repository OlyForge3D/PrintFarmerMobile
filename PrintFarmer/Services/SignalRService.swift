import Foundation

/// SignalR real-time connection to /hubs/printers.
///
/// Broadcasts: printerstatusupdate, printertemperatureupdate,
/// printertoolheadupdate, discoveryprogress, discoveryprinterfound, discoverycompleted
///
/// Implementation deferred until SignalR client package is selected.
/// Candidate packages:
///   - microsoft/signalr-client-swift (official but may lag)
///   - moozzyk/SignalR-Client-Swift (community, mature)
@Observable
final class SignalRService: @unchecked Sendable {
    private(set) var isConnected = false

    private let serverURL: URL
    private let tokenProvider: @Sendable () async -> String?

    init(serverURL: URL, tokenProvider: @escaping @Sendable () async -> String?) {
        self.serverURL = serverURL
        self.tokenProvider = tokenProvider
    }

    func connect() async {
        // TODO: Establish SignalR connection to \(serverURL)/hubs/printers
        // with JWT access token from tokenProvider
    }

    func disconnect() async {
        isConnected = false
    }
}
