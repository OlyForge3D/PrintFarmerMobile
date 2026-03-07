import Foundation

// MARK: - API Client

actor APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var baseURL: URL
    private var accessToken: String?
    private var tokenExpiryChecker: (@Sendable () async -> Bool)?

    /// Key used to persist the server URL across launches.
    static let serverURLKey = "pf_server_url"

    /// ISO 8601 formatter with fractional seconds (matches ASP.NET Core output).
    nonisolated(unsafe) static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// ISO 8601 formatter without fractional seconds (fallback).
    nonisolated(unsafe) static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        self.decoder = JSONDecoder()
        // ASP.NET Core can emit fractional seconds; the built-in .iso8601 strategy
        // rejects them, so we use a custom strategy that tries both formats.
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = Self.iso8601WithFractional.date(from: text) { return date }
            if let date = Self.iso8601Plain.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string: \(text)"
            )
        }

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func setAccessToken(_ token: String?) {
        self.accessToken = token
    }

    /// Registers a closure that checks whether the current token is expired.
    /// Called before each API request to proactively reject expired tokens.
    func setTokenExpiryChecker(_ checker: @escaping @Sendable () async -> Bool) {
        self.tokenExpiryChecker = checker
    }

    func updateBaseURL(_ url: URL) {
        self.baseURL = url
        UserDefaults.standard.set(url.absoluteString, forKey: Self.serverURLKey)
    }

    func currentBaseURL() -> URL {
        baseURL
    }

    func currentAccessToken() -> String? {
        accessToken
    }

    /// Restores a previously-saved server URL from UserDefaults.
    static func savedBaseURL() -> URL? {
        guard let saved = UserDefaults.standard.string(forKey: serverURLKey),
              let url = URL(string: saved) else { return nil }
        return url
    }

    // MARK: - HTTP Methods

    func get<T: Decodable & Sendable>(_ path: String) async throws -> T {
        let request = try buildRequest(path: path, method: "GET")
        return try await execute(request)
    }

    func post<T: Decodable & Sendable, B: Encodable & Sendable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    func getData(_ path: String) async throws -> Data {
        try await checkTokenExpiry()
        let request = try buildRequest(path: path, method: "GET")
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        return data
    }

    func post<T: Decodable & Sendable>(_ path: String) async throws -> T {
        let request = try buildRequest(path: path, method: "POST")
        return try await execute(request)
    }

    func postVoid(_ path: String) async throws {
        let request = try buildRequest(path: path, method: "POST")
        try await executeVoid(request)
    }

    func putVoid(_ path: String) async throws {
        let request = try buildRequest(path: path, method: "PUT")
        try await executeVoid(request)
    }

    func putVoid<B: Encodable & Sendable>(_ path: String, body: B) async throws {
        var request = try buildRequest(path: path, method: "PUT")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await executeVoid(request)
    }

    func put<T: Decodable & Sendable, B: Encodable & Sendable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: path, method: "PUT")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    func delete(_ path: String) async throws {
        let request = try buildRequest(path: path, method: "DELETE")
        try await executeVoid(request)
    }

    // MARK: - Internal

    private func buildRequest(path: String, method: String) throws -> URLRequest {
        // Pre-flight: reject if token is known to be expired
        // (check is sync-safe — the actual async check happens in execute/executeVoid wrappers)
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw NetworkError.invalidURL(path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        try await checkTokenExpiry()
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            let preview = String(data: data.prefix(2000), encoding: .utf8) ?? "<binary>"
            print("⚠️ [APIClient] Decode failed for \(T.self) at \(request.url?.path ?? "?"): \(error)")
            print("⚠️ [APIClient] Response body preview: \(preview)")
            #endif
            throw NetworkError.decodingFailed(error)
        }
    }

    private func executeVoid(_ request: URLRequest) async throws {
        try await checkTokenExpiry()
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
    }

    private func checkTokenExpiry() async throws {
        if let checker = tokenExpiryChecker, await checker() {
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
            throw NetworkError.unauthorized
        }
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                throw NetworkError.noConnection
            case .timedOut:
                throw NetworkError.timeout
            case .cannotFindHost, .cannotConnectToHost:
                throw NetworkError.serverUnreachable
            default:
                throw NetworkError.transportError(error)
            }
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 409:
            throw NetworkError.conflict
        case 400...499:
            let apiError = try? decoder.decode(APIError.self, from: data)
            throw NetworkError.clientError(http.statusCode, apiError)
        case 500...599:
            throw NetworkError.serverError(http.statusCode)
        default:
            throw NetworkError.unexpectedStatus(http.statusCode)
        }
    }
}

// MARK: - Errors

enum NetworkError: LocalizedError, Sendable {
    case invalidURL(String)
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case noConnection
    case timeout
    case serverUnreachable
    case clientError(Int, APIError?)
    case serverError(Int)
    case unexpectedStatus(Int)
    case decodingFailed(Error)
    case transportError(URLError)
    case authFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let path): "Invalid URL: \(path)"
        case .invalidResponse: "Invalid server response"
        case .unauthorized: "Authentication required"
        case .forbidden: "Access denied"
        case .notFound: "Resource not found"
        case .conflict: "Conflict — resource was modified"
        case .noConnection: "No internet connection"
        case .timeout: "Request timed out"
        case .serverUnreachable: "Server is unreachable"
        case .clientError(let code, let apiError):
            apiError?.detail ?? apiError?.title ?? "Client error (\(code))"
        case .serverError(let code): "Server error (\(code))"
        case .unexpectedStatus(let code): "Unexpected status (\(code))"
        case .decodingFailed(let error): "Failed to decode response: \(error.localizedDescription)"
        case .transportError(let error): "Network error: \(error.localizedDescription)"
        case .authFailed(let message): message
        }
    }
}

// MARK: - Session Expired Notification

extension Notification.Name {
    static let sessionExpired = Notification.Name("SessionExpired")
}
