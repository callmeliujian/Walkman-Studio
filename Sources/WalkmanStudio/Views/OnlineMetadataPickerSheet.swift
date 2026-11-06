import SwiftUI

struct OnlineMetadataSelection: Identifiable {
    let id = UUID()
    let query: String
    var candidates: [OnlineTrackMetadata]
}

/// Owns one lookup, so switching tracks or closing an editor cannot apply a stale result.
@MainActor
final class OnlineMetadataLookup: ObservableObject {
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingArtwork = false
    @Published private(set) var isLoadingSource = false
    @Published private(set) var selectedSource: OnlineMetadataSource = .itunes
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
        isSearching = true
        self.onMatch = onMatch
        searchContext = (filename, title, artist, album)
        task = Task {
            let candidates = await service.searchMetadata(filename: filename, currentTitle: title,
                                                          currentArtist: artist, currentAlbum: album)
            guard !Task.isCancelled else { return }
            if candidates.count > 1 {
                selectedSource = OnlineMetadataSource(rawValue: candidates[0].source) ?? .itunes
                cachedCandidates[selectedSource] = candidates
                let terms = OnlineMetadataService.cleanSearchTerms(filename: filename, title: title, artist: artist)
                selection = OnlineMetadataSelection(query: terms.query, candidates: candidates)
            } else if let only = candidates.first {
                await apply(only)
            } else {
                cancel()
                onNotFound()
            }
        }
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
        task = Task {
            let candidates = await service.searchMetadata(filename: context.filename, currentTitle: context.title,
                                                          currentArtist: context.artist, currentAlbum: context.album,
                                                          source: source)
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

struct OnlineMetadataPickerSheet: View {
    @ObservedObject private var localization = AppLocalization.shared
    let selection: OnlineMetadataSelection
    @ObservedObject var lookup: OnlineMetadataLookup
    @State private var selectedID: String?

    private var candidates: [OnlineTrackMetadata] {
        lookup.selection?.candidates ?? []
    }

    private var selected: OnlineTrackMetadata? {
        candidates.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "music.note.magnifyingglass")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(.tint)
                        .frame(width: 48, height: 48)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.tr("Choose a Match"))
                            .font(.system(size: 21, weight: .semibold))
                        Text(L10n.tr("Compare the artist and album before filling in your metadata."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Picker(L10n.tr("Metadata Source"), selection: Binding(
                    get: { lookup.selectedSource },
                    set: { source in
                        selectedID = nil
                        lookup.selectSource(source)
                    }
                )) {
                    ForEach(OnlineMetadataSource.allCases, id: \.self) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(lookup.isLoadingArtwork)
                .padding(.top, 8)

                HStack(alignment: .firstTextBaseline) {
                    Text(selection.query)
                        .font(.callout.weight(.medium))
                        .lineLimit(2)
                        .help(selection.query)
                    Spacer(minLength: 12)
                    Text(lookup.isLoadingSource ? L10n.tr("Searching Online...") : L10n.tr("\(candidates.count) results"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                .padding(.top, 6)
            }
            .padding(24)

            Divider()

            if lookup.isLoadingSource {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(L10n.tr("Searching Online..."))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if candidates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text(L10n.tr("No results available"))
                        .font(.headline)
                    Text(L10n.tr("Try again or choose another source."))
                        .foregroundStyle(.secondary)
                    Button(L10n.tr("Try Again")) {
                        selectedID = nil
                        lookup.selectSource(lookup.selectedSource, reload: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedID) {
                    ForEach(candidates) { candidate in
                        candidateRow(candidate)
                            .tag(candidate.id)
                    }
                }
                .listStyle(.inset)
                .disabled(lookup.isLoadingArtwork)
                .accessibilityLabel(L10n.tr("Online metadata matches"))
            }

            Divider()

            HStack(spacing: 12) {
                if lookup.isLoadingArtwork {
                    ProgressView().controlSize(.small)
                    Text(L10n.tr("Loading artwork…"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.tr(selected == nil ? "Select a result to continue." : "Changes are saved when you save the editor."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button(L10n.tr("Cancel")) { lookup.cancel() }
                    .keyboardShortcut(.cancelAction)
                Button(L10n.tr("Use Selected")) {
                    if let selected { lookup.choose(selected) }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selected == nil || lookup.isLoadingArtwork || lookup.isLoadingSource)
            }
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .frame(width: 700, height: 610)
        .background(.regularMaterial)
        .interactiveDismissDisabled(lookup.isLoadingArtwork)
    }

    private func candidateRow(_ candidate: OnlineTrackMetadata) -> some View {
        HStack(alignment: .center, spacing: 14) {
            AsyncImage(url: candidate.previewArtworkURL ?? candidate.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "music.note").font(.title2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                Text(candidate.artist.isEmpty ? "Unknown Artist" : candidate.artist)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text(candidate.album.isEmpty ? "Unknown Album" : candidate.album)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(details(candidate))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 12) {
                Text(candidate.source)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
                Image(systemName: selectedID == candidate.id ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selectedID == candidate.id ? Color.accentColor : Color.secondary.opacity(0.45))
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .help([candidate.title, candidate.artist, candidate.album, details(candidate)].joined(separator: "\n"))
        .accessibilityElement(children: .combine)
    }

    private func details(_ candidate: OnlineTrackMetadata) -> String {
        var parts = [candidate.year, candidate.genre].filter { !$0.isEmpty }
        if let duration = candidate.durationSeconds, duration.isFinite, duration > 0 {
            let seconds = Int(duration)
            parts.append(String(format: "%d:%02d", seconds / 60, seconds % 60))
        }
        if !candidate.trackNumber.isEmpty { parts.append(L10n.tr("Track \(candidate.trackNumber)")) }
        return parts.isEmpty ? L10n.tr("Additional details unavailable") : parts.joined(separator: " · ")
    }
}

private struct OnlineMetadataPickerModifier<ID: Equatable>: ViewModifier {
    @ObservedObject var lookup: OnlineMetadataLookup
    let identity: ID

    func body(content: Content) -> some View {
        content
            .sheet(item: $lookup.selection, onDismiss: { lookup.cancel() }) { selection in
                OnlineMetadataPickerSheet(selection: selection, lookup: lookup)
            }
            .onChange(of: identity) { _ in lookup.cancel() }
            .onDisappear { lookup.cancel() }
    }
}

extension View {
    func onlineMetadataPicker<ID: Equatable>(_ lookup: OnlineMetadataLookup, identity: ID) -> some View {
        modifier(OnlineMetadataPickerModifier(lookup: lookup, identity: identity))
    }
}
