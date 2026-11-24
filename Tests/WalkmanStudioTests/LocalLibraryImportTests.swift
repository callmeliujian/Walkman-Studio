import XCTest
@testable import WalkmanStudio

final class LocalLibraryImportTests: XCTestCase {
    private var directory: URL!
    private var drive: WalkmanDrive!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mount = directory.appendingPathComponent("Device")
        let music = mount.appendingPathComponent("MUSIC")
        try FileManager.default.createDirectory(at: music, withIntermediateDirectories: true)
        drive = WalkmanDrive(name: "Test Walkman", mountPoint: mount.path, type: .microsd,
                             totalBytes: 0, usedBytes: 0, freeBytes: 0, percentUsed: 0, hasCfw: false, musicDir: music.path)
    }

    override func tearDownWithError() throws {
        let music = URL(fileURLWithPath: drive.musicDir)
        if let files = FileManager.default.enumerator(at: music, includingPropertiesForKeys: nil) {
            for case let file as URL in files where file.pathExtension == "mp3" {
                LibraryScanner.shared.removeFromCache(fullPath: file.path)
            }
        }
        try FileManager.default.removeItem(at: directory)
    }

    private func makeTrack(_ path: String, title: String, album: String, artist: String = "Artist") throws -> Track {
        let url = directory.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0, count: 512).write(to: url)
        try AudioTagger.shared.writeMP3Metadata(fileURL: url, title: title, artist: artist, album: album,
                                              trackNumber: "1", year: "2024", genre: "Pop", coverArtData: nil)
        return Track(filename: url.lastPathComponent, relativePath: path, fullPath: url.path, format: "MP3",
                     title: title, artist: artist, album: album, trackNum: "1", year: "2024", genre: "Pop",
                     durationSeconds: 180, bitrateKbps: 128, sampleRate: 44100, bitsPerSample: 16,
                     hasArtwork: false, sizeBytes: 512)
    }

    @MainActor
    func testImportChecksDeviceAndEarlierCopiesAndIsRepeatable() async throws {
        let existing = try makeTrack("Device/MUSIC/Custom/renamed.mp3", title: "First Song", album: "Original")
        let original = try Data(contentsOf: URL(fileURLWithPath: existing.fullPath))
        let existingCopy = try makeTrack("Mac/a.mp3", title: "First Song", album: "Compilation")
        let newTrack = try makeTrack("Mac/b.mp3", title: "Second Song", album: "Studio")
        let batchCopy = try makeTrack("Mac/c.mp3", title: "Second Song", album: "Collection")
        let cover = try makeTrack("Mac/d.mp3", title: "Second Song", album: "Covers", artist: "Another Singer")
        let tracks = [existingCopy, newTrack, batchCopy, cover]

        let first = try await TransferQueueService.shared.transferWithResult(tracks: tracks, to: drive) { _, _, _ in }
        XCTAssertEqual(first.transferred, 2)
        XCTAssertEqual(first.duplicates, 2)
        XCTAssertEqual(first.missing, 0)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: existing.fullPath)), original)
        let files = try XCTUnwrap(FileManager.default.subpaths(atPath: drive.musicDir))
        XCTAssertEqual(Set(files.filter { $0.hasSuffix(".mp3") }), [
            "Custom/renamed.mp3", "Artist/Studio/01 - Second Song.mp3", "Another Singer/Covers/01 - Second Song.mp3"
        ])

        let repeatImport = try await TransferQueueService.shared.transferWithResult(tracks: tracks, to: drive) { _, _, _ in }
        XCTAssertEqual(repeatImport.transferred, 0)
        XCTAssertEqual(repeatImport.duplicates, tracks.count)
    }

    @MainActor
    func testIgnoresOrphanLyricsAndCountsMissingSourcesSeparately() async throws {
        let available = try makeTrack("Mac/available.mp3", title: "New Song", album: "Album")
        let missing = try makeTrack("Mac/gone.mp3", title: "Missing Song", album: "Album")
        try FileManager.default.removeItem(atPath: missing.fullPath)
        let lyrics = URL(fileURLWithPath: drive.musicDir).appendingPathComponent("Artist/Album/01 - New Song.lrc")
        try FileManager.default.createDirectory(at: lyrics.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "[00:01]Existing lyrics".write(to: lyrics, atomically: true, encoding: .utf8)
        var visited: [Int] = []
        let result = try await TransferQueueService.shared.transferWithResult(tracks: [available, missing], to: drive) { current, _, _ in
            visited.append(current)
        }
        XCTAssertEqual(visited, [1, 2])
        XCTAssertEqual(result.transferred, 1)
        XCTAssertEqual(result.duplicates, 0)
        XCTAssertEqual(result.missing, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: lyrics.deletingPathExtension().appendingPathExtension("mp3").path))
    }
}
