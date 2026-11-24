import XCTest
@testable import WalkmanStudio

final class OnlineMetadataTests: XCTestCase {
    private let results = Data(#"{"results":[{"trackId":1,"trackName":"One Love / People Get Ready","artistName":"Bob Marley","collectionName":"Legend"},{"trackId":2,"trackName":"One Love","artistName":"ARASHI","collectionName":"One Love - Single","trackNumber":1,"releaseDate":"2008-06-25","trackTimeMillis":285000,"primaryGenreName":"J-Pop","artworkUrl100":"https://example.test/100x100bb.jpg"}]}"#.utf8)

    private func service(_ response: @escaping (URLRequest) -> Data?) -> OnlineMetadataService {
        MetadataURLProtocol.respond = response
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MetadataURLProtocol.self]
        return OnlineMetadataService(session: URLSession(configuration: config))
    }

    func testAliasSearchKeepsAllCandidatesWithoutDownloadingArtwork() async {
        let service = service { request in
            XCTAssertEqual(request.url?.host, "itunes.apple.com")
            return self.results
        }
        let matches = await service.searchMetadata(filename: "One Love.flac", currentTitle: "One Love", currentArtist: "嵐")
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches.first?.artist, "ARASHI")
        XCTAssertEqual(matches.first?.year, "2008")
        XCTAssertEqual(matches.first?.durationSeconds, 285)
        XCTAssertNil(matches.first?.artworkData)
        XCTAssertEqual(matches.first?.artworkURL?.absoluteString, "https://example.test/800x800bb.jpg")
    }

    func testDeezerFallbackKeepsEveryResultAndDoesNotInventTrackNumbers() async {
        let service = service { request in
            if request.url?.host == "itunes.apple.com" { return Data(#"{"results":[]}"#.utf8) }
            return Data(#"{"data":[{"id":7,"title":"One Love","artist":{"name":"ARASHI"},"album":{"title":"One Love"},"duration":285},{"id":8,"title":"One Love","artist":{"name":"Blue"},"album":{"title":"One Love"}}]}"#.utf8)
        }
        let matches = await service.searchMetadata(filename: "One Love.flac", currentTitle: "One Love")
        XCTAssertEqual(matches.map(\.source), ["Deezer", "Deezer"])
        XCTAssertEqual(matches.first?.trackNumber, "")
        XCTAssertEqual(matches.first?.durationSeconds, 285)
    }

    func testTitleOnlyFallbackAndEmptyResults() async {
        var calls = 0
        let service = service { request in
            calls += 1
            if calls < 3 { return Data(#"{"results":[],"data":[]}"#.utf8) }
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "term" }?.value
            XCTAssertEqual(query, "One Love")
            return self.results
        }
        let matches = await service.searchMetadata(filename: "One Love.flac", currentTitle: "One Love", currentArtist: "嵐")
        XCTAssertEqual(calls, 3)
        XCTAssertEqual(matches.count, 2)
    }

    func testDeduplicatesOnlyProviderIDsAndPreservesAlbumVersions() {
        let first = OnlineTrackMetadata(title: "One Love", artist: "ARASHI", album: "Single", id: "1")
        let second = OnlineTrackMetadata(title: "One Love", artist: "ARASHI", album: "Compilation", id: "2")
        let ranked = OnlineMetadataService.rankedCandidates([first, first, second], title: "One Love", artist: "ARASHI", album: "Compilation")
        XCTAssertEqual(ranked.map(\.id), ["2", "1"])
    }

    @MainActor
    func testMultipleResultsWaitForExplicitChoice() async throws {
        let lookup = OnlineMetadataLookup(service: service { request in
            request.url?.host == "example.test" ? Data(repeating: 1, count: 2048) : self.results
        })
        var applied: OnlineTrackMetadata?
        lookup.search(filename: "One Love.flac", title: "One Love", artist: "嵐", album: "", onMatch: { applied = $0 }, onNotFound: { XCTFail("Unexpected empty result") })
        try await waitUntil { lookup.selection != nil }
        XCTAssertNil(applied)
        let chosen = try XCTUnwrap(lookup.selection?.candidates.first { $0.artist == "ARASHI" })
        lookup.choose(chosen)
        try await waitUntil { applied != nil }
        XCTAssertEqual(applied?.id, chosen.id)
        XCTAssertEqual(applied?.artworkData?.count, 2048)
        XCTAssertNil(lookup.selection)
        XCTAssertFalse(lookup.isSearching)
    }

    @MainActor
    func testCancelDuringArtworkNeverAppliesAndAllowsNewLookup() async throws {
        let lookup = OnlineMetadataLookup(service: service { request in
            request.url?.host == "example.test" ? nil : self.results
        })
        var applied = false
        lookup.search(filename: "One Love.flac", title: "One Love", artist: "嵐", album: "", onMatch: { _ in applied = true }, onNotFound: {})
        try await waitUntil { lookup.selection != nil }
        lookup.choose(try XCTUnwrap(lookup.selection?.candidates.first))
        try await waitUntil { lookup.isLoadingArtwork }
        lookup.cancel()
        XCTAssertFalse(applied)
        XCTAssertNil(lookup.selection)
        XCTAssertFalse(lookup.isSearching)
        lookup.search(filename: "Next.flac", title: "Next", artist: "", album: "", onMatch: { _ in XCTFail("Must still choose") }, onNotFound: {})
        try await waitUntil { lookup.selection != nil }
        XCTAssertEqual(lookup.selection?.query, "Next")
        XCTAssertFalse(applied)
        lookup.cancel()
    }

    @MainActor
    func testCanChangeRegionWithOneMatchOrNoMatchesAndApplyJapaneseTags() async throws {
        let lookup = OnlineMetadataLookup(service: service { request in
            XCTAssertEqual(request.url?.host, "itunes.apple.com")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
            switch query["country"] {
            case "US":
                XCTAssertEqual(query["lang"], "en_us")
                XCTAssertEqual(query["term"], "One Love 嵐")
                return Data(#"{"results":[{"trackId":2,"trackName":"One Love","artistName":"ARASHI"}]}"#.utf8)
            case "FR":
                XCTAssertEqual(query["lang"], "en_us")
                return Data(#"{"results":[]}"#.utf8)
            case "JP":
                XCTAssertEqual(query["lang"], "ja_jp")
                if query["term"] == "One Love 嵐" { return Data(#"{"results":[]}"#.utf8) }
                XCTAssertEqual(query["term"], "One Love")
                return Data(#"{"results":[{"trackId":2,"trackName":"One Love","artistName":"嵐"}]}"#.utf8)
            default:
                XCTFail("Unexpected storefront")
                return Data(#"{"results":[]}"#.utf8)
            }
        })
        var applied: OnlineTrackMetadata?
        lookup.search(filename: "One Love.flac", title: "One Love", artist: "嵐", album: "", onMatch: { applied = $0 }, onNotFound: { XCTFail("Expected single result") })
        try await waitUntil { lookup.selection != nil }
        let english = try XCTUnwrap(lookup.selection?.candidates.first)
        XCTAssertEqual(english.artist, "ARASHI")
        XCTAssertNil(applied)

        lookup.selectStorefront(ITunesStorefront(countryCode: "FR"))
        try await waitUntil { !lookup.isLoadingSource }
        XCTAssertTrue(lookup.selection?.candidates.isEmpty == true)
        lookup.selectStorefront(ITunesStorefront(countryCode: "JP"))
        try await waitUntil { !lookup.isLoadingSource }
        let japanese = try XCTUnwrap(lookup.selection?.candidates.first)
        lookup.choose(english)
        XCTAssertFalse(lookup.isLoadingArtwork)
        lookup.choose(japanese)
        try await waitUntil { applied != nil }
        XCTAssertEqual(applied?.artist, "嵐")
        XCTAssertNil(lookup.selection)

        lookup.search(filename: "One Love.flac", title: "One Love", artist: "嵐", album: "", onMatch: { _ in }, onNotFound: {})
        try await waitUntil { lookup.selection != nil }
        XCTAssertEqual(lookup.storefront, .unitedStates)
        XCTAssertEqual(lookup.selection?.candidates.first?.artist, "ARASHI")
        lookup.cancel()
    }

    @MainActor
    func testEmptyInitialSearchCanFindARegionalRelease() async throws {
        let lookup = OnlineMetadataLookup(service: service { request in
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            if items?.contains(URLQueryItem(name: "country", value: "JP")) == true {
                return Data(#"{"results":[{"trackId":4,"trackName":"春よ、来い"}]}"#.utf8)
            }
            return Data(#"{"results":[],"data":[]}"#.utf8)
        })
        lookup.search(filename: "春よ、来い.flac", title: "", artist: "", album: "",
                      onMatch: { _ in XCTFail("Must wait for selection") }, onNotFound: { XCTFail("Must allow region changes") })
        try await waitUntil { lookup.selection != nil }
        XCTAssertTrue(lookup.selection?.candidates.isEmpty == true)
        lookup.selectStorefront(ITunesStorefront(countryCode: "JP"))
        try await waitUntil { !lookup.isLoadingSource }
        XCTAssertEqual(lookup.selection?.candidates.first?.title, "春よ、来い")
        lookup.cancel()
    }

    @MainActor
    func testChangingRegionDuringLookupKeepsOnlyLatestResults() async throws {
        let lookup = OnlineMetadataLookup(service: service { request in
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            let country = items?.first { $0.name == "country" }?.value
            if country == "FR" { return nil }
            if country == "JP" {
                return Data(#"{"results":[{"trackId":2,"trackName":"One Love","artistName":"嵐"}]}"#.utf8)
            }
            return self.results
        })
        lookup.search(filename: "One Love.flac", title: "One Love", artist: "嵐", album: "",
                      onMatch: { _ in XCTFail("Unexpected automatic selection") }, onNotFound: {})
        try await waitUntil { lookup.selection != nil }
        lookup.selectStorefront(ITunesStorefront(countryCode: "FR"))
        XCTAssertTrue(lookup.isLoadingSource)
        lookup.selectStorefront(ITunesStorefront(countryCode: "JP"))
        try await waitUntil { !lookup.isLoadingSource }
        XCTAssertEqual(lookup.selection?.candidates.map(\.artist), ["嵐"])
        lookup.cancel()
    }

    @MainActor
    func testCancelledSearchDoesNotOpenPicker() async throws {
        let lookup = OnlineMetadataLookup(service: service { _ in self.results })
        lookup.search(filename: "One Love.flac", title: "One Love", artist: "嵐", album: "", onMatch: { _ in XCTFail("Cancelled") }, onNotFound: { XCTFail("Cancelled") })
        lookup.cancel()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNil(lookup.selection)
        XCTAssertFalse(lookup.isSearching)
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Lookup did not reach expected state")
    }

    func testExplicitSourceNeverFallsBackToAnotherProvider() async {
        let service = service { request in
            XCTAssertEqual(request.url?.host, "api.deezer.com")
            return Data(#"{"data":[]}"#.utf8)
        }
        let matches = await service.searchMetadata(filename: "One Love.flac", currentTitle: "One Love",
                                                   currentArtist: "嵐", source: .deezer)
        XCTAssertTrue(matches.isEmpty)
    }

    @MainActor
    func testSourceSwitchCachesResultsAndRequiresChoiceEvenForOneResult() async throws {
        let lookup = OnlineMetadataLookup(service: service { request in
            if request.url?.host == "api.deezer.com" {
                return Data(#"{"data":[{"id":7,"title":"One Love","artist":{"name":"ARASHI"},"album":{"title":"One Love"}}]}"#.utf8)
            }
            return self.results
        })
        var applied: OnlineTrackMetadata?
        lookup.search(filename: "One Love.flac", title: "One Love", artist: "嵐", album: "",
                      onMatch: { applied = $0 }, onNotFound: { XCTFail("Expected results") })
        try await waitUntil { lookup.selection != nil }
        let sheetID = lookup.selection?.id
        let itunesIDs = lookup.selection?.candidates.map(\.id)
        lookup.selectSource(.deezer)
        XCTAssertTrue(lookup.isLoadingSource)
        XCTAssertTrue(lookup.selection?.candidates.isEmpty == true)
        try await waitUntil { !lookup.isLoadingSource }
        XCTAssertEqual(lookup.selection?.candidates.map(\.id), ["deezer:7"])
        XCTAssertNil(applied)
        XCTAssertEqual(lookup.selection?.id, sheetID)
        lookup.selectSource(.itunes)
        XCTAssertFalse(lookup.isLoadingSource)
        XCTAssertEqual(lookup.selection?.candidates.map(\.id), itunesIDs)
        lookup.selectSource(.deezer)
        XCTAssertFalse(lookup.isLoadingSource)
        lookup.choose(try XCTUnwrap(lookup.selection?.candidates.first))
        try await waitUntil { applied != nil }
        XCTAssertEqual(applied?.source, "Deezer")
    }

    @MainActor
    func testSwitchingBackCancelsPendingSourceAndRejectsOldSelection() async throws {
        let lookup = OnlineMetadataLookup(service: service { request in
            request.url?.host == "api.deezer.com" ? nil : self.results
        })
        lookup.search(filename: "One Love.flac", title: "One Love", artist: "嵐", album: "",
                      onMatch: { _ in XCTFail("Must not apply stale selection") }, onNotFound: {})
        try await waitUntil { lookup.selection != nil }
        let previous = try XCTUnwrap(lookup.selection?.candidates.first)
        lookup.selectSource(.deezer)
        lookup.choose(previous)
        XCTAssertFalse(lookup.isLoadingArtwork)
        lookup.selectSource(.itunes)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(lookup.selectedSource, .itunes)
        XCTAssertFalse(lookup.isLoadingSource)
        XCTAssertEqual(lookup.selection?.candidates.count, 2)
        lookup.cancel()
    }
}
