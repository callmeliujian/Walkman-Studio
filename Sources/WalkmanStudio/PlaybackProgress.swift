import Combine

public final class PlaybackProgress: ObservableObject, @unchecked Sendable {
    @Published public var currentTime: Double = 0.0
    @Published public var duration: Double = 0.0

    public init(currentTime: Double = 0.0, duration: Double = 0.0) {
        self.currentTime = currentTime
        self.duration = duration
    }
}
