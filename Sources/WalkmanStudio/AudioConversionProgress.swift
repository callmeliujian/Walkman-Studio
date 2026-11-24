import Foundation

public struct AudioConversionProgress: Sendable {
    public let processedSeconds: Double
    public let durationSeconds: Double?
    public let isComplete: Bool

    public var fraction: Double? {
        if isComplete { return 1 }
        guard let durationSeconds, durationSeconds > 0 else { return nil }
        // Encoder padding can put the last timestamp past the source duration.
        // Reserve 100% for a successful exit and publication of the output.
        return min(processedSeconds / durationSeconds, 0.999)
    }
}
