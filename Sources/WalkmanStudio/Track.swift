import Foundation

public struct Track: Identifiable, Hashable, Codable, Sendable {
    public var id: String { fullPath }
    public var filename: String
    public var relativePath: String
    public var fullPath: String
    public let format: String // "FLAC", "MP3", "M4A", etc.
    public var title: String
    public var artist: String
    public var album: String
    public var trackNum: String
    public var year: String
    public var genre: String
    public var durationSeconds: Double
    public var bitrateKbps: Int
    public var sampleRate: Int
    public var bitsPerSample: Int
    public var hasArtwork: Bool
    public let sizeBytes: Int64
    public var dateAdded: Date
    public var isSenseMeAnalyzed: Bool
    public var senseMeBpm: Double?
    public var senseMeValence: Double?
    public var senseMeArousal: Double?
    public var senseMeChannels: [String]
    public var senseMeHighlightSec: Double?

    public init(
        filename: String,
        relativePath: String,
        fullPath: String,
        format: String,
        title: String,
        artist: String,
        album: String,
        trackNum: String,
        year: String,
        genre: String,
        durationSeconds: Double,
        bitrateKbps: Int,
        sampleRate: Int,
        bitsPerSample: Int,
        hasArtwork: Bool,
        sizeBytes: Int64,
        dateAdded: Date = Date(),
        isSenseMeAnalyzed: Bool = false,
        senseMeBpm: Double? = nil,
        senseMeValence: Double? = nil,
        senseMeArousal: Double? = nil,
        senseMeChannels: [String] = [],
        senseMeHighlightSec: Double? = nil
    ) {
        self.filename = filename
        self.relativePath = relativePath
        self.fullPath = fullPath
        self.format = format
        self.title = title
        self.artist = artist
        self.album = album
        self.trackNum = trackNum
        self.year = year
        self.genre = genre
        self.durationSeconds = durationSeconds
        self.bitrateKbps = bitrateKbps
        self.sampleRate = sampleRate
        self.bitsPerSample = bitsPerSample
        self.hasArtwork = hasArtwork
        self.sizeBytes = sizeBytes
        self.dateAdded = dateAdded
        self.isSenseMeAnalyzed = isSenseMeAnalyzed
        self.senseMeBpm = senseMeBpm
        self.senseMeValence = senseMeValence
        self.senseMeArousal = senseMeArousal
        self.senseMeChannels = senseMeChannels
        self.senseMeHighlightSec = senseMeHighlightSec
    }
}

extension Track {
    /// Whether this file currently exists on disk (useful for detecting renamed or missing folders/files)
    public var existsOnDisk: Bool {
        FileManager.default.fileExists(atPath: fullPath)
    }

    /// Whether this track qualifies as Hi-Res Audio (exceeds standard 16-bit / 44.1/48kHz CD quality)
    public var isHiRes: Bool {
        bitsPerSample > 16 || sampleRate > 48000
    }

    /// Extracts the primary artist name, stripping guest/featured artists (e.g. "6CycleMind, Ebe Dancel" -> "6CycleMind").
    public var primaryArtist: String {
        Track.parsePrimaryAndFeaturedArtist(from: artist).primary
    }

    /// Whether this track belongs to Language Study mode (/LEARNING/ or language/audiobook/podcast genre)
    public var isLanguageStudy: Bool {
        if fullPath.contains("/LEARNING/") { return true }
        guard !genre.isEmpty else { return false }
        let g = genre.lowercased()
        return g.contains("language") ||
               g.contains("audiobook") ||
               g.contains("podcast") ||
               g.contains("learning")
    }

    /// Extracts any featured or guest artists if present.
    public var featuredArtist: String? {
        Track.parsePrimaryAndFeaturedArtist(from: artist).featured
    }

    /// Checks if a string has balanced parentheses and brackets
    public static func isBalanced(_ text: String) -> Bool {
        var pDepth = 0
        var bDepth = 0
        for ch in text {
            if ch == "(" {
                pDepth += 1
            } else if ch == ")" {
                pDepth -= 1
                if pDepth < 0 { return false }
            } else if ch == "[" {
                bDepth += 1
            } else if ch == "]" {
                bDepth -= 1
                if bDepth < 0 { return false }
            }
        }
        return pDepth == 0 && bDepth == 0
    }

    /// Trims leading and trailing whitespace, as well as trailing punctuation like commas, semicolons, slashes, dashes, ampersands
    public static func cleanTrailingPunctuation(_ text: String) -> String {
        var str = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = str.last, (last == "," || last == ";" || last == "/" || last == "-" || last == "&" || last.isWhitespace) {
            str.removeLast()
            str = str.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return str
    }

    /// Parses an artist string into primary artist and optional featured artist string.
    public static func parsePrimaryAndFeaturedArtist(from raw: String) -> (primary: String, featured: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ("Unknown Artist", nil)
        }

        let lower = trimmed.lowercased()

        // Known artists that contain commas, ampersands, or slashes as part of their official name
        let knownExceptions: [String] = [
            "3d (danao, dancel, dumas)",
            "tyler, the creator",
            "earth, wind & fire",
            "crosby, stills, nash & young",
            "crosby, stills & nash",
            "emerson, lake & palmer",
            "blood, sweat & tears",
            "peter, paul and mary",
            "peter, paul & mary",
            "simon & garfunkel",
            "hall & oates",
            "daryl hall & john oates",
            "brooks & dunn",
            "bell biv devoe",
            "kool & the gang",
            "kc & the sunshine band",
            "sly & the family stone",
            "sly and the family stone",
            "huey lewis & the news",
            "huey lewis and the news",
            "tom petty and the heartbreakers",
            "tom petty & the heartbreakers",
            "bob marley & the wailers",
            "bob marley and the wailers",
            "florence + the machine",
            "florence and the machine",
            "of monsters and men",
            "captain & tennille",
            "katrina and the waves",
            "katrina & the waves",
            "joan jett & the blackhearts",
            "orange & lemons",
            "she & him",
            "ben&ben",
            "ac/dc"
        ]

        for known in knownExceptions {
            if lower == known {
                return (trimmed, nil)
            }
            if lower.hasPrefix(known) {
                let rest = trimmed.dropFirst(known.count).trimmingCharacters(in: .whitespacesAndNewlines)
                if rest.isEmpty {
                    return (trimmed, nil)
                }
                let primary = String(trimmed.prefix(known.count))
                let cleanedFeat = stripLeadingFeatTokens(String(rest))
                return (primary, cleanedFeat.isEmpty ? nil : cleanedFeat)
            }
        }

        // 1. Explicit keyword markers: feat., ft., featuring, with, w/ (case-insensitive)
        let keywords = [" feat. ", " feat ", " ft. ", " ft ", " featuring ", " Featuring ", " with ", " With ", " w/ ", " W/ "]
        for kw in keywords {
            if let range = trimmed.range(of: kw, options: .caseInsensitive) {
                let rawPrimary = String(trimmed[..<range.lowerBound])
                let primary = cleanTrailingPunctuation(rawPrimary)
                let rawFeat = String(trimmed[range.upperBound...])
                let feat = stripLeadingFeatTokens(rawFeat)
                if !primary.isEmpty && isBalanced(primary) && (feat.isEmpty || isBalanced(feat)) {
                    return (primary, feat.isEmpty ? nil : feat)
                }
            }
        }

        // 2. Parenthesized feat: e.g. "Drake (feat. Rihanna)" or "Drake [ft. Rihanna]"
        for (open, close) in [("(", ")"), ("[", "]")] {
            if trimmed.hasSuffix(close), let openIdx = trimmed.range(of: open, options: .backwards)?.lowerBound {
                let primaryRaw = String(trimmed[..<openIdx])
                let primary = cleanTrailingPunctuation(primaryRaw)
                let inside = String(trimmed[openIdx...].dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                let lowerInside = inside.lowercased()
                for prefix in ["feat. ", "feat ", "ft. ", "ft ", "featuring ", "with ", "w/ "] {
                    if lowerInside.hasPrefix(prefix) {
                        let feat = stripLeadingFeatTokens(String(inside.dropFirst(prefix.count)))
                        if !primary.isEmpty && isBalanced(primary) && (feat.isEmpty || isBalanced(feat)) {
                            return (primary, feat.isEmpty ? nil : feat)
                        }
                    }
                }
            }
        }

        // 3. Delimiters at nesting depth 0: comma (", "), semicolon ("; "), forward slashes (" / ", " // ")
        // NEVER split inside parentheses or brackets! (e.g. "3D (Danao, Dancel, Dumas)" must stay intact)
        let delimiters = ["; ", " // ", " / ", ", "]

        var pDepth = 0
        var bDepth = 0
        var earliestDelimRange: Range<String.Index>? = nil

        var currIdx = trimmed.startIndex
        while currIdx < trimmed.endIndex {
            let ch = trimmed[currIdx]
            if ch == "(" {
                pDepth += 1
            } else if ch == ")" {
                pDepth = max(0, pDepth - 1)
            } else if ch == "[" {
                bDepth += 1
            } else if ch == "]" {
                bDepth = max(0, bDepth - 1)
            } else if pDepth == 0 && bDepth == 0 {
                let remaining = trimmed[currIdx...]
                for delim in delimiters {
                    if remaining.hasPrefix(delim) {
                        let endIdx = trimmed.index(currIdx, offsetBy: delim.count)
                        earliestDelimRange = currIdx..<endIdx
                        break
                    }
                }
                if earliestDelimRange != nil {
                    break
                }
            }
            currIdx = trimmed.index(after: currIdx)
        }

        if let range = earliestDelimRange {
            let rawPrimary = String(trimmed[..<range.lowerBound])
            let primary = cleanTrailingPunctuation(rawPrimary)
            let rawFeat = String(trimmed[range.upperBound...])
            let feat = stripLeadingFeatTokens(rawFeat)
            if !primary.isEmpty && !feat.isEmpty && isBalanced(primary) && isBalanced(feat) {
                return (primary, feat)
            }
        }

        return (trimmed, nil)
    }

    public static func stripLeadingFeatTokens(_ text: String) -> String {
        var str = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while str.hasPrefix(",") || str.hasPrefix(";") || str.hasPrefix("/") || str.hasPrefix("-") || str.hasPrefix("&") {
            str = String(str.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let lower = str.lowercased()
        for prefix in ["feat. ", "feat ", "ft. ", "ft ", "featuring ", "with ", "w/ "] {
            if lower.hasPrefix(prefix) {
                return String(str.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return str
    }

    /// Formats the guest/featured artists for display on track rows.
    /// Returns nil if track title already contains feat information or if no guest is present.
    public func featuredDisplayString(primaryArtist: String? = nil) -> String? {
        let lowerTitle = title.lowercased()
        if lowerTitle.contains("feat.") || lowerTitle.contains("feat ") || lowerTitle.contains("ft.") || lowerTitle.contains("featuring") {
            return nil
        }

        let raw = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let parsed = Track.parsePrimaryAndFeaturedArtist(from: raw)
        if let feat = parsed.featured, !feat.isEmpty, Track.isBalanced(feat) {
            return feat
        }

        if let pa = primaryArtist, !pa.isEmpty, raw.localizedCaseInsensitiveCompare(pa) != .orderedSame {
            if raw.lowercased().hasPrefix(pa.lowercased()) {
                let rest = raw.dropFirst(pa.count)
                let cleaned = Track.stripLeadingFeatTokens(String(rest))
                if !cleaned.isEmpty && Track.isBalanced(cleaned) {
                    return cleaned
                }
            }
        }

        return nil
    }
}
