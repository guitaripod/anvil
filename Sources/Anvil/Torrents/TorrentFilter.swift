import UIKit

enum TorrentFilter: Int, CaseIterable, Sendable {
    case all, downloading, seeding, completed, stopped, errored

    var title: String {
        switch self {
        case .all: return "All"
        case .downloading: return "Downloading"
        case .seeding: return "Seeding"
        case .completed: return "Completed"
        case .stopped: return "Paused"
        case .errored: return "Errored"
        }
    }

    var apiValue: String {
        switch self {
        case .all: return "all"
        case .downloading: return "downloading"
        case .seeding: return "seeding"
        case .completed: return "completed"
        case .stopped: return "stopped"
        case .errored: return "errored"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "tray.full.fill"
        case .downloading: return "arrow.down.circle.fill"
        case .seeding: return "arrow.up.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .stopped: return "pause.circle.fill"
        case .errored: return "exclamationmark.triangle.fill"
        }
    }

    var tint: UIColor {
        switch self {
        case .all: return Theme.accent
        case .downloading: return Theme.downloadColor
        case .seeding: return Theme.uploadColor
        case .completed: return .systemGreen
        case .stopped: return Theme.pausedColor
        case .errored: return Theme.errorColor
        }
    }
}
