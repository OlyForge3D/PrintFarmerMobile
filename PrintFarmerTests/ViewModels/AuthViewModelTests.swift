import XCTest
@testable import PrintFarmer

/// AuthViewModel tests. AuthViewModel depends on the concrete AuthService actor,
/// so we use MockURLProtocol to intercept network calls at the URLSession layer.
/// This validates the full AuthViewModel → AuthService → APIClient path.
@MainActor
final class AuthViewModelTests: XCTestCase {

    private var apiClient: APIClient!
    private var authService: AuthService!
    private var viewModel: AuthViewModel!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        apiClient = MockAPIClient.makeAPIClient()
        authService = AuthService(apiClient: apiClient)
        viewModel = AuthViewModel(authService: authService)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        UserDefaults.standard.removeObject(forKey: APIClient.serverURLKey)
        viewModel = nil
        authService = nil
        apiClient = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNil(viewModel.currentUser)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Login Success

    func testLoginSuccessSetsAuthenticated() async {
        MockAPIClient.stubResponse(json: TestJSON.authResponseSuccess)

        await viewModel.login(serverURL: "https://print.example.com", username: "admin", password: "password")

        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertNotNil(viewModel.currentUser)
        XCTAssertEqual(viewModel.currentUser?.username, "admin")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Login Errors

    func testLoginUnauthorizedSetsMessage() async {
        MockAPIClient.stubResponse(json: "{}", statusCode: 401)

        await viewModel.login(serverURL: "https://print.example.com", username: "admin", password: "wrong")

        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoginForbiddenSetsMessage() async {
        MockAPIClient.stubResponse(json: "{}", statusCode: 403)

        await viewModel.login(serverURL: "https://print.example.com", username: "admin", password: "password")

        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("access") ?? false)
    }

    func testLoginServerErrorSetsMessage() async {
        MockAPIClient.stubResponse(json: "{}", statusCode: 500)

        await viewModel.login(serverURL: "https://print.example.com", username: "admin", password: "password")

        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoginNetworkErrorSetsMessage() async {
        MockAPIClient.stubError(.notConnectedToInternet)

        await viewModel.login(serverURL: "https://print.example.com", username: "admin", password: "password")

        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testLoginClearsErrorOnSuccess() async {
        MockAPIClient.stubResponse(json: "{}", statusCode: 401)
        await viewModel.login(serverURL: "https://print.example.com", username: "admin", password: "wrong")
        XCTAssertNotNil(viewModel.errorMessage)

        MockAPIClient.stubResponse(json: TestJSON.authResponseSuccess)
        await viewModel.login(serverURL: "https://print.example.com", username: "admin", password: "password")

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.isAuthenticated)
    }

    // MARK: - Logout

    func testLogoutClearsState() async {
        MockAPIClient.stubResponse(json: TestJSON.authResponseSuccess)
        await viewModel.login(serverURL: "https://print.example.com", username: "admin", password: "password")
        XCTAssertTrue(viewModel.isAuthenticated)

        await viewModel.logout()

        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNil(viewModel.currentUser)
    }

    // MARK: - Session Restore

    func testRestoreSessionWithNoToken() async {
        await viewModel.restoreSession()

        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNil(viewModel.currentUser)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testRestoreSessionCompletesLoadingCycle() async {
        MockAPIClient.stubResponse(json: TestJSON.userDTO)
        await viewModel.restoreSession()
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Session Expired Notification

    func testSessionExpiredNotificationTriggersLogout() async {
        MockAPIClient.stubResponse(json: TestJSON.authResponseSuccess)
        await viewModel.login(serverURL: "https://print.example.com", username: "admin", password: "password")
        XCTAssertTrue(viewModel.isAuthenticated)

        NotificationCenter.default.post(name: .sessionExpired, object: nil)

        // Give the async Task time to process
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNil(viewModel.currentUser)
    }
}
