import SwiftUI

public enum LocalSortOption: String, CaseIterable, Identifiable, Sendable {
    case titleAZ = "Title (A–Z)"
    case titleZA = "Title (Z–A)"
    case artistAZ = "Artist (A–Z)"
    case albumAZ = "Album (A–Z)"
    case dateNewest = "Date Added (Newest)"
    case dateOldest = "Date Added (Oldest)"
    case duration = "Duration (Longest)"
    case bitrate = "Audio Quality / Bitrate"

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .titleAZ: return L10n.tr("Title (A–Z)")
        case .titleZA: return L10n.tr("Title (Z–A)")
        case .artistAZ: return L10n.tr("Artist")
        case .albumAZ: return L10n.tr("Album")
        case .dateNewest: return L10n.tr("Newest")
        case .dateOldest: return L10n.tr("Oldest")
        case .duration: return L10n.tr("Duration")
        case .bitrate: return L10n.tr("Quality")
        }
    }

    public var iconName: String {
        switch self {
        case .titleAZ:
            return "arrow.up.and.down.text.horizontal"
        case .titleZA:
            return "arrow.down.and.line.horizontal.and.arrow.up"
        case .artistAZ:
            return "person.fill"
        case .albumAZ:
            return "square.stack.fill"
        case .dateNewest:
            return "clock.fill"
        case .dateOldest:
            return "calendar"
        case .duration:
            return "timer"
        case .bitrate:
            return "waveform"
        }
    }
}
