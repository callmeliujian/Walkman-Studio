import Foundation

/// Narrows a batch lookup to the two keys that can match in WalkmanDuplicateGuard.
struct WalkmanImportIndex {
    private var byTitle: [String: [Track]] = [:]
    private var byFilename: [String: [Track]] = [:]

    init(tracks: [Track]) {
        for track in tracks { insert(track) }
    }

    mutating func insert(_ track: Track) {
        byTitle[DuplicateFinderService.normalizeTitle(track.title), default: []].append(track)
        byFilename[track.filename.lowercased(), default: []].append(track)
    }

    func candidates(title: String, filename: String) -> [Track] {
        let titleMatches = byTitle[DuplicateFinderService.normalizeTitle(title)] ?? []
        let filenameMatches = byFilename[filename.lowercased()] ?? []
        return titleMatches + filenameMatches
    }
}
