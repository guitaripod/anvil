import Foundation
import os

enum APIError: Error, LocalizedError, Sendable {
    case invalidURL
    case httpError(statusCode: Int, message: String)
    case decodingError(String)
    case noServerConfigured
    case loginFailed(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .httpError(let code, let message): return "HTTP \(code): \(message)"
        case .decodingError(let detail): return "Decode failed: \(detail)"
        case .noServerConfigured: return "No server configured"
        case .loginFailed(let detail): return "Login failed: \(detail)"
        case .unauthorized: return "Session expired"
        }
    }
}

actor APIClient {
    nonisolated let session: ServerSession
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private var hasLoggedIn = false
    private let log = Logger(subsystem: "com.guitaripod.anvil", category: "api")

    init(session: ServerSession) {
        self.session = session
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.urlSession = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    func login() async throws {
        let endpoint = QBitEndpoint.login(username: session.username, password: session.password)
        let request = try endpoint.urlRequest(baseURL: session.baseURL)
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidURL
        }
        let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 403 {
                throw APIError.loginFailed("User banned or IP blocked. Try again later.")
            }
            throw APIError.loginFailed("HTTP \(http.statusCode): \(body)")
        }
        if body.range(of: "fail", options: .caseInsensitive) != nil {
            throw APIError.loginFailed("Invalid username or password")
        }
        hasLoggedIn = true
    }

    func ensureLoggedIn() async throws {
        guard !hasLoggedIn else { return }
        try await login()
    }

    func request<T: Decodable & Sendable>(_ endpoint: QBitEndpoint) async throws -> T {
        let data = try await rawRequest(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let preview = String(data: data.prefix(500), encoding: .utf8) ?? "non-utf8"
            log.error("Decode \(T.self) failed: \(error)\nBody: \(preview)")
            throw APIError.decodingError("\(error)")
        }
    }

    func requestVoid(_ endpoint: QBitEndpoint) async throws {
        _ = try await rawRequest(endpoint)
    }

    func requestString(_ endpoint: QBitEndpoint) async throws -> String {
        let data = try await rawRequest(endpoint)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func rawRequest(_ endpoint: QBitEndpoint, isRetry: Bool = false) async throws -> Data {
        try await ensureLoggedIn()
        let urlRequest = try endpoint.urlRequest(baseURL: session.baseURL)
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidURL
        }
        if http.statusCode == 403 && !isRetry {
            hasLoggedIn = false
            try await login()
            return try await rawRequest(endpoint, isRetry: true)
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(statusCode: http.statusCode, message: body)
        }
        return data
    }

    nonisolated static func probe(baseURL: URL) async -> Bool {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v2/app/version"))
        request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")
        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                return http.statusCode < 500
            }
            return false
        } catch {
            return false
        }
    }
}
