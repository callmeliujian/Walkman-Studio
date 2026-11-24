import SwiftUI

public enum LocalDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case songs = "Songs"
    case albums = "Albums"
    case artists = "Artists"
    case recentlyAdded = "Recently Added"
    case folders = "Folders"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .songs: return "music.note.list"
        case .albums: return "square.stack.fill"
        case .artists: return "music.mic"
        case .recentlyAdded: return "clock.arrow.circlepath"
        case .folders: return "folder.fill"
        }
    }
}
