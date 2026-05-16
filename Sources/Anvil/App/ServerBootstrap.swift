import Foundation

struct ServerSession: Sendable, Equatable {
    let baseURL: URL
    let username: String
    let password: String
}

enum ServerBootstrap {
    private static let baseURLKey = "anvil_base_url"
    private static let usernameKey = "anvil_username"
    private static let passwordKey = "anvil_password"
    private static let lastURLKey = "anvil_last_base_url"

    static let defaultPort = 8080

    static func session() -> ServerSession? {
        guard let urlString = UserDefaults.standard.string(forKey: baseURLKey),
              let url = URL(string: urlString),
              let username = UserDefaults.standard.string(forKey: usernameKey),
              let password = KeychainHelper.load(key: passwordKey)
        else { return nil }
        return ServerSession(baseURL: url, username: username, password: password)
    }

    static func save(baseURL: URL, username: String, password: String) {
        UserDefaults.standard.set(baseURL.absoluteString, forKey: baseURLKey)
        UserDefaults.standard.set(username, forKey: usernameKey)
        KeychainHelper.save(key: passwordKey, value: password)
        setLastBaseURL(baseURL)
    }

    static func lastBaseURL() -> URL? {
        guard let raw = UserDefaults.standard.string(forKey: lastURLKey) else { return nil }
        return URL(string: raw)
    }

    static func setLastBaseURL(_ url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: lastURLKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: baseURLKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
        KeychainHelper.delete(key: passwordKey)
    }
}
