import Foundation

public struct DuplicateCheckResult: Sendable {
    public let isDuplicate: Bool
    public let matchingTrack: Track?
    public let reason: String?

    public init(isDuplicate: Bool, matchingTrack: Track? = nil, reason: String? = nil) {
        self.isDuplicate = isDuplicate
        self.matchingTrack = matchingTrack
        self.reason = reason
    }
}
