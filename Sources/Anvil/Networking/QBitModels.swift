import Foundation

struct Torrent: Decodable, Sendable, Hashable, Identifiable {
    let hash: String
    let name: String
    let size: Int64
    let totalSize: Int64
    let progress: Double
    let dlspeed: Int64
    let upspeed: Int64
    let priority: Int
    let numSeeds: Int
    let numComplete: Int
    let numLeechs: Int
    let numIncomplete: Int
    let ratio: Double
    let eta: Int64
    let state: String
    let category: String
    let tags: String
    let addedOn: Int64
    let completionOn: Int64
    let downloaded: Int64
    let uploaded: Int64
    let amountLeft: Int64
    let savePath: String
    let contentPath: String
    let magnetUri: String
    let availability: Double
    let timeActive: Int64
    let trackersCount: Int
    let seenComplete: Int64
    let lastActivity: Int64
    let forceStart: Bool
    let autoTmm: Bool
    let isPrivate: Bool?

    var id: String { hash }

    enum CodingKeys: String, CodingKey {
        case hash, name, size, progress, dlspeed, upspeed, priority
        case totalSize = "total_size"
        case numSeeds = "num_seeds"
        case numComplete = "num_complete"
        case numLeechs = "num_leechs"
        case numIncomplete = "num_incomplete"
        case ratio, eta, state, category, tags, downloaded, uploaded, availability
        case addedOn = "added_on"
        case completionOn = "completion_on"
        case amountLeft = "amount_left"
        case savePath = "save_path"
        case contentPath = "content_path"
        case magnetUri = "magnet_uri"
        case timeActive = "time_active"
        case trackersCount = "trackers_count"
        case seenComplete = "seen_complete"
        case lastActivity = "last_activity"
        case forceStart = "force_start"
        case autoTmm = "auto_tmm"
        case isPrivate = "private"
    }
}

struct TransferInfo: Decodable, Sendable, Hashable {
    let connectionStatus: String
    let dhtNodes: Int
    let dlInfoData: Int64
    let dlInfoSpeed: Int64
    let dlRateLimit: Int64
    let upInfoData: Int64
    let upInfoSpeed: Int64
    let upRateLimit: Int64

    enum CodingKeys: String, CodingKey {
        case connectionStatus = "connection_status"
        case dhtNodes = "dht_nodes"
        case dlInfoData = "dl_info_data"
        case dlInfoSpeed = "dl_info_speed"
        case dlRateLimit = "dl_rate_limit"
        case upInfoData = "up_info_data"
        case upInfoSpeed = "up_info_speed"
        case upRateLimit = "up_rate_limit"
    }
}

struct TorrentProperties: Decodable, Sendable, Hashable {
    let additionDate: Int64
    let completionDate: Int64
    let creationDate: Int64
    let createdBy: String
    let comment: String
    let pieceSize: Int64
    let piecesHave: Int
    let piecesNum: Int
    let totalSize: Int64
    let totalDownloaded: Int64
    let totalUploaded: Int64
    let totalDownloadedSession: Int64
    let totalUploadedSession: Int64
    let totalWasted: Int64
    let dlSpeedAvg: Int64
    let upSpeedAvg: Int64
    let dlSpeed: Int64
    let upSpeed: Int64
    let shareRatio: Double
    let timeElapsed: Int64
    let seedingTime: Int64
    let nbConnections: Int
    let nbConnectionsLimit: Int
    let seeds: Int
    let seedsTotal: Int
    let peers: Int
    let peersTotal: Int
    let savePath: String
    let downloadPath: String
    let lastSeen: Int64
    let reannounce: Int64
    let eta: Int64
    let isPrivate: Bool?

    enum CodingKeys: String, CodingKey {
        case additionDate = "addition_date"
        case completionDate = "completion_date"
        case creationDate = "creation_date"
        case createdBy = "created_by"
        case comment
        case pieceSize = "piece_size"
        case piecesHave = "pieces_have"
        case piecesNum = "pieces_num"
        case totalSize = "total_size"
        case totalDownloaded = "total_downloaded"
        case totalUploaded = "total_uploaded"
        case totalDownloadedSession = "total_downloaded_session"
        case totalUploadedSession = "total_uploaded_session"
        case totalWasted = "total_wasted"
        case dlSpeedAvg = "dl_speed_avg"
        case upSpeedAvg = "up_speed_avg"
        case dlSpeed = "dl_speed"
        case upSpeed = "up_speed"
        case shareRatio = "share_ratio"
        case timeElapsed = "time_elapsed"
        case seedingTime = "seeding_time"
        case nbConnections = "nb_connections"
        case nbConnectionsLimit = "nb_connections_limit"
        case seeds
        case seedsTotal = "seeds_total"
        case peers
        case peersTotal = "peers_total"
        case savePath = "save_path"
        case downloadPath = "download_path"
        case lastSeen = "last_seen"
        case reannounce
        case eta
        case isPrivate = "is_private"
    }
}

struct TorrentFile: Decodable, Sendable, Hashable {
    let index: Int
    let name: String
    let size: Int64
    let progress: Double
    let priority: Int
    let isSeed: Bool?
    let availability: Double
    let pieceRange: [Int]?

    enum CodingKeys: String, CodingKey {
        case index, name, size, progress, priority, availability
        case isSeed = "is_seed"
        case pieceRange = "piece_range"
    }
}

struct Tracker: Decodable, Sendable, Hashable {
    let url: String
    let status: Int
    let tier: Int
    let numPeers: Int
    let numSeeds: Int
    let numLeeches: Int
    let numDownloaded: Int
    let msg: String

    enum CodingKeys: String, CodingKey {
        case url, status, tier, msg
        case numPeers = "num_peers"
        case numSeeds = "num_seeds"
        case numLeeches = "num_leeches"
        case numDownloaded = "num_downloaded"
    }
}

enum TorrentState: Sendable {
    case error, missingFiles
    case uploading, stalledUP, queuedUP, checkingUP, forcedUP, pausedUP, stoppedUP
    case downloading, metaDL, stalledDL, queuedDL, checkingDL, forcedDL, pausedDL, stoppedDL, allocating
    case checkingResumeData, moving, unknown

    static func parse(_ raw: String) -> TorrentState {
        switch raw {
        case "error": return .error
        case "missingFiles": return .missingFiles
        case "uploading": return .uploading
        case "stalledUP": return .stalledUP
        case "queuedUP": return .queuedUP
        case "checkingUP": return .checkingUP
        case "forcedUP": return .forcedUP
        case "pausedUP": return .pausedUP
        case "stoppedUP": return .stoppedUP
        case "downloading": return .downloading
        case "metaDL": return .metaDL
        case "stalledDL": return .stalledDL
        case "queuedDL": return .queuedDL
        case "checkingDL": return .checkingDL
        case "forcedDL": return .forcedDL
        case "pausedDL": return .pausedDL
        case "stoppedDL": return .stoppedDL
        case "allocating": return .allocating
        case "checkingResumeData": return .checkingResumeData
        case "moving": return .moving
        default: return .unknown
        }
    }

    var isStopped: Bool {
        switch self {
        case .pausedUP, .pausedDL, .stoppedUP, .stoppedDL: return true
        default: return false
        }
    }

    var isDownloading: Bool {
        switch self {
        case .downloading, .metaDL, .stalledDL, .queuedDL, .forcedDL, .allocating: return true
        default: return false
        }
    }

    var isSeeding: Bool {
        switch self {
        case .uploading, .stalledUP, .queuedUP, .forcedUP: return true
        default: return false
        }
    }

    var isErrored: Bool {
        switch self {
        case .error, .missingFiles: return true
        default: return false
        }
    }

    var isCompleted: Bool {
        switch self {
        case .uploading, .stalledUP, .queuedUP, .checkingUP, .forcedUP, .pausedUP, .stoppedUP: return true
        default: return false
        }
    }
}
