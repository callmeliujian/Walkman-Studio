import XCTest
@testable import WalkmanStudio

final class LocalLibraryReconciliationTests: XCTestCase {
    func testRenameRemovesOldMemoryEntryEvenAfterDatabaseRowWasDeleted() {
        let stale = LocalMusicLibraryService.staleTrackPaths(
            folderURL: URL(fileURLWithPath: "/Music"),
            cachedPaths: ["/Music/Local/new.mp3"],
            inMemoryPaths: ["/Music/Local/old.mp3", "/Music/Local/new.mp3"],
            discoveredPaths: ["/Music/Local/new.mp3"]
        )
        XCTAssertEqual(stale, ["/Music/Local/old.mp3"])
    }

    func testChildScanPreservesParentAndSimilarlyNamedSiblingFolders() {
        let stale = LocalMusicLibraryService.staleTrackPaths(
            folderURL: URL(fileURLWithPath: "/Music/Local"),
            cachedPaths: [],
            inMemoryPaths: ["/Music/song.mp3", "/Music/Local Backup/song.mp3", "/Music/Local/old.mp3"],
            discoveredPaths: []
        )
        XCTAssertEqual(stale, ["/Music/Local/old.mp3"])
    }

    func testDistinctFilesRemainEvenWhenTheyRepresentTheSameSong() {
        let paths: Set<String> = ["/Music/song.mp3", "/Music/song.flac"]
        let stale = LocalMusicLibraryService.staleTrackPaths(
            folderURL: URL(fileURLWithPath: "/Music"),
            cachedPaths: paths,
            inMemoryPaths: paths,
            discoveredPaths: paths
        )
        XCTAssertTrue(stale.isEmpty)
    }
}
