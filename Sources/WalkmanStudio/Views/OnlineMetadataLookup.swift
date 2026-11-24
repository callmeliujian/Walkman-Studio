import SwiftUI

/// Owns one lookup, so switching tracks or closing an editor cannot apply a stale result.
@MainActor
final class OnlineMetadataLookup: ObservableObject {
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingArtwork = false
    @Published private(set) var isLoadingSource = false
    @Published private(set) var selectedSource: OnlineMetadataSource = .itunes
    @Published private(set) var storefront: ITunesStorefront = .unitedStates
    @Published var selection: OnlineMetadataSelection?
    private let service: OnlineMetadataService
    private var task: Task<Void, Never>?
    private var onMatch: ((OnlineTrackMetadata) -> Void)?
    private var searchContext: (filename: String, title: String, artist: String, album: String)?
    private var cachedCandidates: [OnlineMetadataSource: [OnlineTrackMetadata]] = [:]

    init(service: OnlineMetadataService = .shared) {
        self.service = service
    }

    func search(filename: String, title: String, artist: String, album: String,
                onMatch: @escaping (OnlineTrackMetadata) -> Void, onNotFound: @escaping () -> Void) {
        cancel()
        let terms = OnlineMetadataService.cleanSearchTerms(filename: filename, title: title, artist: artist)
        guard !terms.query.isEmpty else {
            onNotFound()
            return
        }
        storefront = .unitedStates
        isSearching = true
        self.onMatch = onMatch
        searchContext = (filename, title, artist, album)
        task = Task {
            let candidates = await service.searchMetadata(filename: filename, currentTitle: title,
                                                          currentArtist: artist, currentAlbum: album)
            guard !Task.isCancelled else { return }
            selectedSource = candidates.first.flatMap { OnlineMetadataSource(rawValue: $0.source) } ?? .itunes
            cachedCandidates[selectedSource] = candidates
            selection = OnlineMetadataSelection(query: terms.query, candidates: candidates)
        }
    }

    func selectStorefront(_ storefront: ITunesStorefront) {
        guard selection != nil, selectedSource == .itunes, !isLoadingArtwork, storefront != self.storefront else { return }
        self.storefront = storefront
        cachedCandidates[.itunes] = nil
        selectSource(.itunes, reload: true)
    }

    func selectSource(_ source: OnlineMetadataSource, reload: Bool = false) {
        guard selection != nil, !isLoadingArtwork, let context = searchContext else { return }
        guard source != selectedSource || reload else { return }
        task?.cancel()
        task = nil
        selectedSource = source
        selection?.candidates = []
        if !reload, let cached = cachedCandidates[source] {
            selection?.candidates = cached
            isLoadingSource = false
            return
        }
        isLoadingSource = true
        task = Task { [storefront] in
            let candidates = await service.searchMetadata(filename: context.filename, currentTitle: context.title,
                                                          currentArtist: context.artist, currentAlbum: context.album,
                                                          source: source, storefront: storefront)
            guard !Task.isCancelled else { return }
            cachedCandidates[source] = candidates
            selection?.candidates = candidates
            isLoadingSource = false
        }
    }

    func choose(_ candidate: OnlineTrackMetadata) {
        guard !isLoadingSource, !isLoadingArtwork,
              selection?.candidates.contains(where: { $0.id == candidate.id }) == true else { return }
        isLoadingArtwork = true
        task = Task { await apply(candidate) }
    }

    private func apply(_ candidate: OnlineTrackMetadata) async {
        guard !Task.isCancelled else { return }
        isLoadingArtwork = true
        let metadata = await service.loadArtwork(for: candidate)
        guard !Task.isCancelled else { return }
        let completion = onMatch
        selection = nil
        isSearching = false
        isLoadingArtwork = false
        onMatch = nil
        searchContext = nil
        cachedCandidates = [:]
        task = nil
        completion?(metadata)
    }

    func cancel() {
        task?.cancel()
        task = nil
        selection = nil
        onMatch = nil
        isSearching = false
        isLoadingArtwork = false
        isLoadingSource = false
        searchContext = nil
        cachedCandidates = [:]
    }
}
