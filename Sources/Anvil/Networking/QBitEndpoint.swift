import Foundation

enum QBitEndpoint: Sendable {
    case login(username: String, password: String)
    case logout
    case version
    case preferences
    case transferInfo

    case torrentsInfo(filter: String? = nil, category: String? = nil, sort: String? = nil, reverse: Bool = false, limit: Int? = nil, offset: Int? = nil)
    case torrentProperties(hash: String)
    case torrentFiles(hash: String)
    case torrentTrackers(hash: String)

    case start(hashes: [String])
    case stop(hashes: [String])
    case forceStart(hashes: [String], value: Bool)
    case delete(hashes: [String], deleteFiles: Bool)
    case recheck(hashes: [String])
    case reannounce(hashes: [String])
    case setLocation(hashes: [String], location: String)
    case rename(hash: String, name: String)
    case setCategory(hashes: [String], category: String)

    case addTorrentByURL(urls: String, savepath: String?, category: String?, paused: Bool, skipChecking: Bool)

    case categories

    var method: String {
        switch self {
        case .login, .logout, .start, .stop, .forceStart, .delete, .recheck, .reannounce,
             .setLocation, .rename, .setCategory, .addTorrentByURL:
            return "POST"
        default:
            return "GET"
        }
    }

    var path: String {
        switch self {
        case .login: return "/api/v2/auth/login"
        case .logout: return "/api/v2/auth/logout"
        case .version: return "/api/v2/app/version"
        case .preferences: return "/api/v2/app/preferences"
        case .transferInfo: return "/api/v2/transfer/info"
        case .torrentsInfo: return "/api/v2/torrents/info"
        case .torrentProperties: return "/api/v2/torrents/properties"
        case .torrentFiles: return "/api/v2/torrents/files"
        case .torrentTrackers: return "/api/v2/torrents/trackers"
        case .start: return "/api/v2/torrents/start"
        case .stop: return "/api/v2/torrents/stop"
        case .forceStart: return "/api/v2/torrents/setForceStart"
        case .delete: return "/api/v2/torrents/delete"
        case .recheck: return "/api/v2/torrents/recheck"
        case .reannounce: return "/api/v2/torrents/reannounce"
        case .setLocation: return "/api/v2/torrents/setLocation"
        case .rename: return "/api/v2/torrents/rename"
        case .setCategory: return "/api/v2/torrents/setCategory"
        case .addTorrentByURL: return "/api/v2/torrents/add"
        case .categories: return "/api/v2/torrents/categories"
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .torrentsInfo(let filter, let category, let sort, let reverse, let limit, let offset):
            var items: [URLQueryItem] = []
            if let filter { items.append(URLQueryItem(name: "filter", value: filter)) }
            if let category { items.append(URLQueryItem(name: "category", value: category)) }
            if let sort { items.append(URLQueryItem(name: "sort", value: sort)) }
            if reverse { items.append(URLQueryItem(name: "reverse", value: "true")) }
            if let limit { items.append(URLQueryItem(name: "limit", value: "\(limit)")) }
            if let offset { items.append(URLQueryItem(name: "offset", value: "\(offset)")) }
            return items.isEmpty ? nil : items
        case .torrentProperties(let hash), .torrentFiles(let hash), .torrentTrackers(let hash):
            return [URLQueryItem(name: "hash", value: hash)]
        default:
            return nil
        }
    }

    var formBody: String? {
        switch self {
        case .login(let username, let password):
            return form(["username": username, "password": password])
        case .start(let hashes):
            return form(["hashes": hashes.joined(separator: "|")])
        case .stop(let hashes):
            return form(["hashes": hashes.joined(separator: "|")])
        case .forceStart(let hashes, let value):
            return form(["hashes": hashes.joined(separator: "|"), "value": value ? "true" : "false"])
        case .delete(let hashes, let deleteFiles):
            return form(["hashes": hashes.joined(separator: "|"), "deleteFiles": deleteFiles ? "true" : "false"])
        case .recheck(let hashes):
            return form(["hashes": hashes.joined(separator: "|")])
        case .reannounce(let hashes):
            return form(["hashes": hashes.joined(separator: "|")])
        case .setLocation(let hashes, let location):
            return form(["hashes": hashes.joined(separator: "|"), "location": location])
        case .rename(let hash, let name):
            return form(["hash": hash, "name": name])
        case .setCategory(let hashes, let category):
            return form(["hashes": hashes.joined(separator: "|"), "category": category])
        case .addTorrentByURL(let urls, let savepath, let category, let paused, let skipChecking):
            var params: [String: String] = ["urls": urls]
            if let savepath, !savepath.isEmpty { params["savepath"] = savepath }
            if let category, !category.isEmpty { params["category"] = category }
            params["paused"] = paused ? "true" : "false"
            params["skip_checking"] = skipChecking ? "true" : "false"
            return form(params)
        default:
            return nil
        }
    }

    private func form(_ params: [String: String]) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+")
        return params.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
    }

    func urlRequest(baseURL: URL) throws -> URLRequest {
        let trimmed = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: trimmed + path) else {
            throw APIError.invalidURL
        }
        if let queryItems {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue("Anvil/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        if let body = formBody {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = body.data(using: .utf8)
        }
        return request
    }
}
