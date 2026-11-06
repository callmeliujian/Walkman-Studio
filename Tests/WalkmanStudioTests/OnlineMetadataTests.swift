import XCTest
@testable import WalkmanStudio

private final class MetadataURLProtocol: URLProtocol {
    static var respond: (URLRequest) -> Data? = { _ in nil }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let data = Self.respond(request) else { return }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

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
    func testSingleResultAppliesDirectlyAndEmptyResultReportsNotFound() async throws {
        let lookup = OnlineMetadataLookup(service: service { _ in
            Data(#"{"results":[{"trackId":2,"trackName":"One Love","artistName":"ARASHI"}]}"#.utf8)
        })
        var applied: OnlineTrackMetadata?
        lookup.search(filename: "One Love.flac", title: "One Love", artist: "嵐", album: "", onMatch: { applied = $0 }, onNotFound: { XCTFail("Expected single result") })
        try await waitUntil { applied != nil }
        XCTAssertNil(lookup.selection)
        XCTAssertFalse(lookup.isSearching)
        let empty = OnlineMetadataLookup(service: service { _ in Data(#"{"results":[],"data":[]}"#.utf8) })
        var notFound = false
        empty.search(filename: "Missing.flac", title: "Missing", artist: "", album: "", onMatch: { _ in XCTFail("Must not apply") }, onNotFound: { notFound = true })
        try await waitUntil { notFound }
        XCTAssertFalse(empty.isSearching)
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
