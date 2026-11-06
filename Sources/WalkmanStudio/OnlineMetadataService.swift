import Foundation
import CoreGraphics
import ImageIO
import AppKit

public enum OnlineMetadataSource: String, CaseIterable, Sendable {
    case itunes = "iTunes"
    case deezer = "Deezer"
}

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

/// Service to query public music databases (Apple iTunes Search API & Deezer API)
/// to fetch track metadata (Title, Artist, Album, Track #, Year, Genre) and high-resolution album artwork.
public final class OnlineMetadataService: @unchecked Sendable {
    public static let shared = OnlineMetadataService()

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            return
        }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6.0
        config.timeoutIntervalForResource = 12.0
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
    }

    /// Cleans a raw filename or title string into clean search terms
    public static func cleanSearchTerms(filename: String, title: String? = nil, artist: String? = nil) -> (title: String, artist: String, query: String) {
        let cleanTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = (artist ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanTitle.isEmpty && cleanTitle.lowercased() != "unknown" && cleanTitle.lowercased() != "unknown title" && cleanTitle.lowercased() != "unknown track" {
            let sanitizedT = WalkmanEngine.sanitizeWalkmanText(cleanTitle)
            let art = (cleanArtist.isEmpty || cleanArtist.lowercased() == "unknown artist" || cleanArtist.lowercased() == "unknown") ? "" : WalkmanEngine.sanitizeWalkmanText(cleanArtist, stripExplicitMarkers: false)
            let q = art.isEmpty ? sanitizedT : "\(sanitizedT) \(art)"
            return (sanitizedT, art, q)
        }

        // Clean filename
        var stem = filename
        stem = stem.replacingOccurrences(
            of: #"\.(flac|mp3|m4a|wav|aac|ogg|wma|aiff?|dsf|dff)$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Strip leading track numbers like "01. ", "02 - ", "1-03 ", "01 "
        stem = stem.replacingOccurrences(
            of: #"^(\d+[-_])?\d+[\s\.\-_]+"#,
            with: "",
            options: .regularExpression
        )

        // Strip web / video junk like [Official Video], (Lyrics), (Audio), [Remastered 2021], etc., as well as explicit badges
        stem = stem.replacingOccurrences(
            of: #"\s*[\(\[](official\s*(music\s*)?video|video|audio|lyrics?(\s*video)?|visualizer|hd|4k|hq|remaster(ed)?|deluxe|bonus|anniversary|edit|radio\s*edit|explicit(\s*content)?|e).*?[\)\]]"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        stem = WalkmanEngine.sanitizeWalkmanText(stem)

        // If stem contains " - ", it's usually "Artist - Title" or "Title - Artist"
        if stem.contains(" - ") {
            let parts = stem.components(separatedBy: " - ")
            if parts.count >= 2 {
                let p0 = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let p1 = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let isP0Unknown = p0.isEmpty || p0.lowercased() == "unknown" || p0.lowercased() == "unknown artist"
                let isP1Unknown = p1.isEmpty || p1.lowercased() == "unknown" || p1.lowercased() == "unknown track" || p1.lowercased() == "unknown title"

                if !isP1Unknown && !isP0Unknown {
                    return (p1, p0, "\(p0) \(p1)")
                } else if !isP1Unknown {
                    return (p1, "", p1)
                } else if !isP0Unknown {
                    return (p0, "", p0)
                }
            }
        }

        let q = stem.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.lowercased() == "unknown" || q.lowercased() == "unknown track" || q.lowercased() == "unknown title" || q.lowercased() == "unknown artist" {
            return ("", "", "")
        }
        return (q, "", q)
    }

    /// Interactive callers must inspect all candidates before applying metadata.
    /// Artwork is deliberately loaded only after a candidate has been chosen.
    public func searchMetadata(
        filename: String,
        currentTitle: String? = nil,
        currentArtist: String? = nil,
        currentAlbum: String? = nil,
        source: OnlineMetadataSource? = nil
    ) async -> [OnlineTrackMetadata] {
        let terms = Self.cleanSearchTerms(filename: filename, title: currentTitle, artist: currentArtist)
        guard !terms.query.isEmpty, !Task.isCancelled else { return [] }

        // A manually selected tab must never silently fall back to another provider.
        if let source {
            var candidates = await query(source: source, terms: terms.query)
            if candidates.isEmpty && !Task.isCancelled && !terms.artist.isEmpty && !terms.title.isEmpty {
                candidates = await query(source: source, terms: terms.title)
            }
            guard !Task.isCancelled else { return [] }
            return Self.rankedCandidates(candidates, title: terms.title, artist: terms.artist, album: currentAlbum ?? "")
        }

        var candidates = await queryiTunes(query: terms.query)
        if candidates.isEmpty && !Task.isCancelled {
            candidates = await queryDeezer(query: terms.query)
        }
        if candidates.isEmpty && !Task.isCancelled && !terms.artist.isEmpty && !terms.title.isEmpty {
            candidates = await queryiTunes(query: terms.title)
        }
        guard !Task.isCancelled else { return [] }
        return Self.rankedCandidates(candidates, title: terms.title, artist: terms.artist, album: currentAlbum ?? "")
    }

    private func query(source: OnlineMetadataSource, terms: String) async -> [OnlineTrackMetadata] {
        switch source {
        case .itunes: return await queryiTunes(query: terms)
        case .deezer: return await queryDeezer(query: terms)
        }
    }

    /// Compatibility path for noninteractive queue optimization.
    public func fetchMetadata(
        filename: String,
        currentTitle: String? = nil,
        currentArtist: String? = nil,
        currentAlbum: String? = nil
    ) async -> OnlineTrackMetadata? {
        let candidates = await searchMetadata(filename: filename, currentTitle: currentTitle,
                                              currentArtist: currentArtist, currentAlbum: currentAlbum)
        guard let first = candidates.first else { return nil }
        return await loadArtwork(for: first)
    }

    public func loadArtwork(for candidate: OnlineTrackMetadata) async -> OnlineTrackMetadata {
        guard candidate.artworkData == nil, let url = candidate.artworkURL, !Task.isCancelled else { return candidate }
        let data = await downloadImage(from: url)
        return OnlineTrackMetadata(
            title: candidate.title, artist: candidate.artist, album: candidate.album,
            trackNumber: candidate.trackNumber, year: candidate.year, genre: candidate.genre,
            artworkData: data, artworkURL: candidate.artworkURL, source: candidate.source,
            id: candidate.id, durationSeconds: candidate.durationSeconds, previewArtworkURL: candidate.previewArtworkURL
        )
    }

    public func fetchArtworkOnly(title: String, artist: String, album: String = "") async -> Data? {
        let query = "\(title) \(artist)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        let itunes = Self.rankedCandidates(await queryiTunes(query: query), title: title, artist: artist, album: album)
        if let first = itunes.first, let data = await loadArtwork(for: first).artworkData { return data }
        guard !Task.isCancelled else { return nil }
        let deezer = Self.rankedCandidates(await queryDeezer(query: query), title: title, artist: artist, album: album)
        if let first = deezer.first { return await loadArtwork(for: first).artworkData }
        return nil
    }

    private func queryiTunes(query: String) async -> [OnlineTrackMetadata] {
        let results = await search(query: query, endpoint: "https://itunes.apple.com/search",
                                   queryName: "term", extra: [URLQueryItem(name: "entity", value: "song")], resultKey: "results")
        return results.compactMap { item in
            guard let trackID = item["trackId"] as? Int,
                  let title = item["trackName"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let preview = (item["artworkUrl100"] as? String).flatMap(URL.init(string:))
            let artwork = preview.flatMap {
                URL(string: $0.absoluteString.replacingOccurrences(of: "100x100bb", with: "800x800bb")
                    .replacingOccurrences(of: "60x60bb", with: "800x800bb"))
            }
            return OnlineTrackMetadata(
                title: WalkmanEngine.sanitizeWalkmanText(title),
                artist: WalkmanEngine.sanitizeWalkmanText(item["artistName"] as? String ?? "", stripExplicitMarkers: false),
                album: WalkmanEngine.sanitizeWalkmanText(item["collectionName"] as? String ?? ""),
                trackNumber: (item["trackNumber"] as? Int).map(String.init) ?? "",
                year: (item["releaseDate"] as? String).map { String($0.prefix(4)) } ?? "",
                genre: item["primaryGenreName"] as? String ?? "",
                artworkURL: artwork, source: "iTunes", id: "itunes:\(trackID)",
                durationSeconds: (item["trackTimeMillis"] as? Double).map { $0 / 1000 },
                previewArtworkURL: preview
            )
        }
    }

    private func queryDeezer(query: String) async -> [OnlineTrackMetadata] {
        let results = await search(query: query, endpoint: "https://api.deezer.com/search",
                                   queryName: "q", resultKey: "data")
        return results.compactMap { item in
            guard let trackID = item["id"] as? Int,
                  let title = item["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let artist = item["artist"] as? [String: Any]
            let album = item["album"] as? [String: Any]
            let cover = (album?["cover_xl"] as? String) ?? (album?["cover_big"] as? String) ?? (album?["cover_medium"] as? String)
            return OnlineTrackMetadata(
                title: WalkmanEngine.sanitizeWalkmanText(title),
                artist: WalkmanEngine.sanitizeWalkmanText(artist?["name"] as? String ?? "", stripExplicitMarkers: false),
                album: WalkmanEngine.sanitizeWalkmanText(album?["title"] as? String ?? ""),
                artworkURL: cover.flatMap(URL.init(string:)), source: "Deezer", id: "deezer:\(trackID)",
                durationSeconds: item["duration"] as? Double,
                previewArtworkURL: (album?["cover_medium"] as? String).flatMap(URL.init(string:))
            )
        }
    }

    private func search(query: String, endpoint: String, queryName: String,
                        extra: [URLQueryItem] = [], resultKey: String) async -> [[String: Any]] {
        guard !Task.isCancelled, var components = URLComponents(string: endpoint) else { return [] }
        components.queryItems = [URLQueryItem(name: queryName, value: query), URLQueryItem(name: "limit", value: "25")] + extra
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("WalkmanStudio/3.1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 6
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return json[resultKey] as? [[String: Any]] ?? []
    }

    /// Ranking changes order only: artist aliases must never hide valid alternatives.
    static func rankedCandidates(_ candidates: [OnlineTrackMetadata], title: String, artist: String, album: String) -> [OnlineTrackMetadata] {
        func normalized(_ value: String) -> String {
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func match(_ value: String, _ expected: String) -> Int {
            let value = normalized(value), expected = normalized(expected)
            guard !value.isEmpty, !expected.isEmpty else { return 0 }
            if value == expected { return 2 }
            return value.contains(expected) || expected.contains(value) ? 1 : 0
        }
        func score(_ item: OnlineTrackMetadata) -> Int {
            match(item.title, title) * 4 + match(item.artist, artist) * 3 + match(item.album, album) * 2
        }
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.id).inserted }.enumerated().sorted {
            let left = score($0.element), right = score($1.element)
            return left == right ? $0.offset < $1.offset : left > right
        }.map(\.element)
    }

    private func downloadImage(from url: URL) async -> Data? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 7.0
        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              data.count > 1024 else {
            return nil
        }
        return data
    }
}
