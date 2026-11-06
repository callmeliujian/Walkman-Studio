import XCTest
@testable import WalkmanStudio

final class AudioFileRenamerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    @discardableResult
    private func file(_ name: String, content: String = "audio") throws -> URL {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
        return url
    }

    func testRenamesAudioAndDownloadedLyricsToMatchingNames() throws {
        let source = try file("Lambsey_-_PLANET_(mp3.pm).mp3")
        try WalkmanEngine.shared.writeCompanionLyrics(destinationAudioURL: source, lyrics: "[00:01.00]Planet", durationSeconds: 243)
        let result = try AudioFileRenamer.rename(fileURL: source, title: " Planet ", artist: " Lambsey ")
        XCTAssertEqual(result.lastPathComponent, "Planet Lambsey.mp3")
        XCTAssertEqual(try String(contentsOf: result), "audio")
        XCTAssertTrue(try String(contentsOf: result.deletingPathExtension().appendingPathExtension("lrc")).contains("Planet"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.deletingPathExtension().appendingPathExtension("lrc").path))
        XCTAssertEqual(try AudioFileRenamer.rename(fileURL: result, title: "Planet", artist: "Lambsey"), result)
    }

    func testCollisionsPreserveBothExistingAudioAndLyrics() throws {
        let source = try file("old.FLAC")
        try file("old.LRC", content: "lyrics")
        let occupiedAudio = try file("Planet Lambsey.FLAC", content: "other song")
        let occupiedLyrics = try file("Planet Lambsey (2).lrc", content: "other lyrics")
        let result = try AudioFileRenamer.rename(fileURL: source, title: "Planet", artist: "Lambsey")
        XCTAssertEqual(result.lastPathComponent, "Planet Lambsey (3).FLAC")
        XCTAssertEqual(try String(contentsOf: result.deletingPathExtension().appendingPathExtension("LRC")), "lyrics")
        XCTAssertEqual(try String(contentsOf: occupiedAudio), "other song")
        XCTAssertEqual(try String(contentsOf: occupiedLyrics), "other lyrics")
    }

    func testCaseOnlyRenameAndUppercaseLyrics() throws {
        let source = try file("planet lambsey.mp3")
        try file("planet lambsey.LRC", content: "lyrics")
        let result = try AudioFileRenamer.rename(fileURL: source, title: "Planet", artist: "Lambsey")
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(result.lastPathComponent, "Planet Lambsey.mp3")
        XCTAssertTrue(names.contains("Planet Lambsey.mp3"))
        XCTAssertTrue(names.contains("Planet Lambsey.LRC"))
    }

    func testMissingMetadataKeepsOriginalFilename() throws {
        let source = try file("old.mp3")
        XCTAssertEqual(try AudioFileRenamer.rename(fileURL: source, title: " ", artist: "Lambsey"), source)
        XCTAssertEqual(try AudioFileRenamer.rename(fileURL: source, title: "Planet", artist: "\n"), source)
    }

    func testInvalidCharactersAndLongUnicodeNamesStayWithinDirectory() throws {
        let source = try file("old.mp3")
        let result = try AudioFileRenamer.rename(fileURL: source, title: "../夜曲:雨?", artist: "艺术家/歌手")
        XCTAssertEqual(result.lastPathComponent, "夜曲雨 艺术家歌手.mp3")
        XCTAssertEqual(result.deletingLastPathComponent().path, directory.path)
        let long = try AudioFileRenamer.rename(fileURL: result, title: String(repeating: "歌", count: 240), artist: "歌手")
        XCTAssertLessThanOrEqual(long.lastPathComponent.utf8.count, 255)
        XCTAssertTrue(FileManager.default.fileExists(atPath: long.path))
    }

    func testPlaylistPathsFollowRenameWhileCommentsAndOtherSongsStayIntact() throws {
        let source = try file("Album/old.mp3")
        let playlist = try file("favorites.m3u8", content: "\u{FEFF}#EXTM3U\r\n#EXTINF:243,old.mp3\r\nAlbum/old.mp3\r\nAlbum\\old.mp3\r\nOther/old.mp3\r\n")
        _ = try AudioFileRenamer.rename(fileURL: source, title: "Planet", artist: "Lambsey", relativePath: "Album/old.mp3")
        XCTAssertEqual(String(data: try Data(contentsOf: playlist), encoding: .utf8), "\u{FEFF}#EXTM3U\r\n#EXTINF:243,old.mp3\r\nAlbum/Planet Lambsey.mp3\r\nAlbum\\Planet Lambsey.mp3\r\nOther/old.mp3\r\n")
    }
}
