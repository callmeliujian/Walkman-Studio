import Foundation

public struct OnlineTrackMetadata: Sendable, Identifiable {
    public let id: String
    public let durationSeconds: Double?
    public let previewArtworkURL: URL?
    public let title: String
    public let artist: String
    public let album: String
    public let trackNumber: String
    public let year: String
    public let genre: String
    public let artworkData: Data?
    public let artworkURL: URL?
    public let source: String

    public init(
        title: String,
        artist: String,
        album: String,
        trackNumber: String = "",
        year: String = "",
        genre: String = "",
        artworkData: Data? = nil,
        artworkURL: URL? = nil,
        source: String = "iTunes",
        id: String = UUID().uuidString,
        durationSeconds: Double? = nil,
        previewArtworkURL: URL? = nil
    ) {
        self.id = id
        self.durationSeconds = durationSeconds
        self.previewArtworkURL = previewArtworkURL
        self.title = title
        self.artist = artist
        self.album = album
        self.trackNumber = trackNumber
        self.year = year
        self.genre = genre
        self.artworkData = artworkData
        self.artworkURL = artworkURL
        self.source = source
    }
}
