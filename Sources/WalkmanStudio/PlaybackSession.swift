import Foundation

struct PlaybackSession: Codable {
    private static let defaultsKey = "WalkmanStudio.playbackSession.v1"

    let track: Track?
    let position: Double
    let isShuffle: Bool
    let repeatMode: PlaybackRepeatMode
    private let pointA: Double?
    private let pointB: Double?

    init(track: Track?, position: Double, isShuffle: Bool, repeatMode: PlaybackRepeatMode,
         abRepeat: ABRepeatState = .off) {
        self.track = track
        self.position = position
        self.isShuffle = isShuffle
        self.repeatMode = repeatMode
        pointA = abRepeat.start
        pointB = abRepeat.range?.upperBound
    }

    var abRepeat: ABRepeatState {
        guard let track, let pointA, ABRepeatState.off.canAdvance(at: pointA, duration: track.durationSeconds) else {
            return .off
        }
        let marked = ABRepeatState.startMarked(pointA)
        guard let pointB, marked.canAdvance(at: pointB, duration: track.durationSeconds), pointB > pointA else {
            return marked
        }
        return .looping(pointA..<pointB)
    }

    var resumePosition: Double {
        // Quitting as the playhead reaches B should resume at A on the next launch.
        if let range = abRepeat.range, !range.contains(position) { return range.lowerBound }
        guard let track, position.isFinite, position > 0 else { return 0 }
        return track.durationSeconds > 0 ? min(position, track.durationSeconds) : position
    }

    static func load(from defaults: UserDefaults) -> Self? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? PropertyListDecoder().decode(Self.self, from: data)
    }

    func save(to defaults: UserDefaults) {
        if let data = try? PropertyListEncoder().encode(self) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
