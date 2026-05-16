import UIKit

enum Theme {
    static let accent = UIColor.systemTeal
    static let accentSubtle = UIColor.systemTeal.withAlphaComponent(0.15)

    static let downloadColor = UIColor.systemBlue
    static let uploadColor = UIColor.systemGreen
    static let errorColor = UIColor.systemRed
    static let pausedColor = UIColor.systemGray
    static let checkingColor = UIColor.systemOrange
    static let queuedColor = UIColor.systemPurple

    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 6
    static let cornerRadiusLarge: CGFloat = 16

    static let padding: CGFloat = 16
    static let spacingSmall: CGFloat = 8
    static let spacing: CGFloat = 10
    static let spacingMedium: CGFloat = 12
    static let buttonHeight: CGFloat = 50

    static func color(for state: TorrentState) -> UIColor {
        switch state {
        case .error, .missingFiles: return errorColor
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP: return pausedColor
        case .checkingDL, .checkingUP, .checkingResumeData, .moving, .allocating: return checkingColor
        case .queuedDL, .queuedUP: return queuedColor
        case .uploading, .stalledUP, .forcedUP: return uploadColor
        case .downloading, .metaDL, .stalledDL, .forcedDL: return downloadColor
        case .unknown: return .systemGray
        }
    }

    static func shortLabel(for state: TorrentState) -> String {
        switch state {
        case .error: return "Error"
        case .missingFiles: return "Missing"
        case .uploading: return "Seeding"
        case .stalledUP: return "Stalled"
        case .queuedUP: return "Queued"
        case .checkingUP: return "Checking"
        case .forcedUP: return "Forced"
        case .pausedUP, .stoppedUP: return "Completed"
        case .downloading: return "Downloading"
        case .metaDL: return "Metadata"
        case .stalledDL: return "Stalled"
        case .queuedDL: return "Queued"
        case .checkingDL: return "Checking"
        case .forcedDL: return "Forced"
        case .pausedDL, .stoppedDL: return "Paused"
        case .allocating: return "Allocating"
        case .checkingResumeData: return "Checking"
        case .moving: return "Moving"
        case .unknown: return "Unknown"
        }
    }

    static func icon(for state: TorrentState) -> String {
        switch state {
        case .error, .missingFiles: return "exclamationmark.triangle.fill"
        case .pausedUP, .stoppedUP: return "checkmark.circle.fill"
        case .pausedDL, .stoppedDL: return "pause.circle.fill"
        case .checkingDL, .checkingUP, .checkingResumeData: return "magnifyingglass.circle.fill"
        case .moving: return "folder.fill"
        case .allocating: return "square.dashed"
        case .queuedDL, .queuedUP: return "hourglass"
        case .uploading, .stalledUP, .forcedUP: return "arrow.up.circle.fill"
        case .downloading, .metaDL, .stalledDL, .forcedDL: return "arrow.down.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}
