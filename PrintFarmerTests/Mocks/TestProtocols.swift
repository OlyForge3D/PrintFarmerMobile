import Foundation
@testable import PrintFarmer

// MARK: - Test-only Protocol
// Auth has no production protocol yet. Define one here for mock testing.
// The production AuthService is an actor — this lets us test auth flows
// with a mock without hitting Keychain or network.

protocol AuthServiceProtocol: Sendable {
    func login(serverURL: String, username: String, password: String) async throws -> AuthResponse
    func logout() async
    func restoreSession() async -> UserDTO?
    func currentUser() async throws -> UserDTO
    var isAuthenticated: Bool { get async }
}

// NOTE: PrinterServiceProtocol, JobServiceProtocol, NotificationServiceProtocol,
// and StatisticsServiceProtocol are now defined in production code
// at PrintFarmer/Protocols/. Do NOT redefine them here.
