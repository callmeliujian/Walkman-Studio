enum PlaybackRepeatMode: String, Codable {
    case off
    case all
    case one

    var next: Self {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    var symbolName: String {
        self == .one ? "repeat.1" : "repeat"
    }

    var helpText: String {
        switch self {
        case .off: return L10n.tr("Repeat: Off")
        case .all: return L10n.tr("Repeat All")
        case .one: return L10n.tr("Repeat One")
        }
    }
}
