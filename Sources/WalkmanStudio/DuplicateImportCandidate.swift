import Foundation

public struct DuplicateImportCandidate: Identifiable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let title: String
    public let artist: String
    public let album: String
    public let durationSeconds: Double
    public let matchingWalkmanTrack: Track?
    public let matchReason: String
    public let destinationDriveName: String

    public init(
        url: URL,
        title: String,
        artist: String,
        album: String,
        durationSeconds: Double = 0,
        matchingWalkmanTrack: Track? = nil,
        matchReason: String,
        destinationDriveName: String = "Walkman"
    ) {
        self.url = url
        self.title = title
        self.artist = artist
        self.album = album
        self.durationSeconds = durationSeconds
        self.matchingWalkmanTrack = matchingWalkmanTrack
        self.matchReason = matchReason
        self.destinationDriveName = destinationDriveName
    }

    public var destinationRelativePath: String? {
        guard let track = matchingWalkmanTrack else { return nil }
        if !track.relativePath.isEmpty {
            return track.relativePath.hasPrefix("/") ? track.relativePath : "/\(track.relativePath)"
        }
        return (track.fullPath as NSString).lastPathComponent
    }

    public var destinationQualityDescription: String? {
        guard let track = matchingWalkmanTrack else { return nil }
        var parts: [String] = []
        if !track.format.isEmpty { parts.append(track.format.uppercased()) }
        if track.bitsPerSample > 0 && track.sampleRate > 0 {
            parts.append("\(track.bitsPerSample)b/\(track.sampleRate / 1000)k")
        } else if track.bitrateKbps > 0 {
            parts.append("\(track.bitrateKbps) kbps")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}
