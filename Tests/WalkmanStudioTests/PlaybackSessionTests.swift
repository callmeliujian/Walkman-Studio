import AVFoundation
import Combine
import XCTest
@testable import WalkmanStudio

final class PlaybackSessionTests: XCTestCase {
    private let suiteName = "PlaybackSessionTests." + UUID().uuidString
    private var defaults: UserDefaults { UserDefaults(suiteName: suiteName)! }
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try FileManager.default.removeItem(at: directory)
    }

    @MainActor
    func testRelaunchLoadsTrackPausedAtSavedSeekWithBothModes() async throws {
        let track = try makeTrack()
        do {
            let player = AudioPlayerService(defaults: defaults)
            player.play(track: track, in: [track])
            player.isShuffle = true
            player.repeatMode = .one
            player.seek(to: 2.75)
            // Closing or quitting immediately after scrubbing must retain the target.
            player.savePlaybackSession()
            XCTAssertTrue(player.isPlaying)
        }

        let restored = AudioPlayerService(defaults: defaults)
        restored.fallbackTracksProvider = { [track] }
        let seekFinished = expectation(description: "AVPlayer finishes restoring the playhead")
        let seeks = restored.$isSeeking.drop(while: { !$0 }).first(where: { !$0 })
            .sink { _ in seekFinished.fulfill() }
        defer { seeks.cancel() }
        restored.restorePlaybackSessionIfAvailable()
        restored.savePlaybackSession()
        XCTAssertEqual(PlaybackSession.load(from: defaults)?.position, 2.75)
        await fulfillment(of: [seekFinished], timeout: 5)
        XCTAssertEqual(restored.currentTrack?.id, track.id)
        XCTAssertEqual(restored.currentTime, 2.75, accuracy: 0.06)
        XCTAssertFalse(restored.isPlaying)
        XCTAssertNil(restored.currentHighlightStartTime)
        XCTAssertTrue(restored.isShuffle)
        XCTAssertEqual(restored.repeatMode, .one)

        let checkpoint = expectation(description: "Playback advances and writes a new checkpoint")
        let times = restored.progress.$currentTime.first(where: { $0 > 8 })
            .sink { _ in checkpoint.fulfill() }
        defer { times.cancel() }
        restored.play()
        restored.restorePlaybackSessionIfAvailable()
        await fulfillment(of: [checkpoint], timeout: 10)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(PlaybackSession.load(from: defaults)).position, 7.75)
        restored.stopAndClear()

        let cleared = AudioPlayerService(defaults: defaults)
        cleared.restorePlaybackSessionIfAvailable()
        XCTAssertNil(cleared.currentTrack)
        XCTAssertTrue(cleared.isShuffle)
        XCTAssertEqual(cleared.repeatMode, .one)
    }

    @MainActor
    func testRestoredLoopStartsPausedThenPlaysToSavedBTwice() async throws {
        let track = try makeTrack()
        do {
            let player = AudioPlayerService(defaults: defaults)
            player.play(track: track, in: [track], startTime: 2)
            player.advanceABRepeat()
            player.seek(to: 2.6)
            player.advanceABRepeat()
            player.seek(to: 2.3)
        }

        let restored = AudioPlayerService(defaults: defaults)
        defer { restored.stopAndClear() }
        restored.restorePlaybackSessionIfAvailable()
        XCTAssertEqual(restored.abRepeat, .looping(2..<2.6))
        XCTAssertEqual(restored.currentTime, 2.3)
        XCTAssertFalse(restored.isPlaying)
        let repeated = expectation(description: "Restored AVPlayer item reaches B twice")
        repeated.expectedFulfillmentCount = 2
        let ends = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .compactMap { $0.object as? AVPlayerItem }
            .filter { ($0.asset as? AVURLAsset)?.url.path == track.fullPath }
            .prefix(2)
            .sink { item in
                XCTAssertEqual(item.forwardPlaybackEndTime.seconds, 2.6, accuracy: 0.001)
                repeated.fulfill()
            }
        defer { ends.cancel() }
        restored.play()
        await fulfillment(of: [repeated], timeout: 6)
        restored.clearABRepeat()
        XCTAssertEqual(PlaybackSession.load(from: defaults)?.abRepeat, .off)
    }

    @MainActor
    func testUnfinishedMarkerCanBeCompletedOrClearedAfterRelaunch() throws {
        let track = try makeTrack()
        do {
            let player = AudioPlayerService(defaults: defaults)
            player.prepare(track: track, in: [track], startTime: 2)
            player.advanceABRepeat()
        }
        do {
            let player = AudioPlayerService(defaults: defaults)
            player.restorePlaybackSessionIfAvailable()
            XCTAssertEqual(player.abRepeat, .startMarked(2))
            player.seek(to: 3)
            player.advanceABRepeat()
            XCTAssertEqual(PlaybackSession.load(from: defaults)?.abRepeat, .looping(2..<3))
            player.advanceABRepeat()
        }
        let restored = AudioPlayerService(defaults: defaults)
        restored.restorePlaybackSessionIfAvailable()
        XCTAssertEqual(restored.abRepeat, .off)
        XCTAssertEqual(restored.currentTrack?.id, track.id)
    }

    func testSavedLoopRestartsAtAWhenQuittingAtB() throws {
        let track = try makeTrack()
        let session = PlaybackSession(track: track, position: 4, isShuffle: false, repeatMode: .off,
                                      abRepeat: .looping(2..<4))
        session.save(to: defaults)
        XCTAssertEqual(PlaybackSession.load(from: defaults)?.resumePosition, 2)
    }

    func testSessionFromBeforeABRepeatStillRestoresPositionAndModes() throws {
        let track = try makeTrack()
        let encodedTrack = try PropertyListEncoder().encode(track)
        let legacy: [String: Any] = [
            "track": try PropertyListSerialization.propertyList(from: encodedTrack, format: nil),
            "position": 3.5, "isShuffle": true, "repeatMode": "all"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: legacy, format: .binary, options: 0)
        defaults.set(data, forKey: "WalkmanStudio.playbackSession.v1")
        let session = try XCTUnwrap(PlaybackSession.load(from: defaults))
        XCTAssertEqual(session.track?.id, track.id)
        XCTAssertEqual(session.abRepeat, .off)
        XCTAssertEqual(session.resumePosition, 3.5)
        XCTAssertTrue(session.isShuffle)
        XCTAssertEqual(session.repeatMode, .all)
    }

    @MainActor
    func testUnavailableFileKeepsPositionUntilItReturns() throws {
        let track = try makeTrack()
        let url = URL(fileURLWithPath: track.fullPath)
        let offline = directory.appendingPathComponent("offline.caf")
        try FileManager.default.moveItem(at: url, to: offline)
        PlaybackSession(track: track, position: 3, isShuffle: false, repeatMode: .all,
                        abRepeat: .looping(2..<4)).save(to: defaults)

        let player = AudioPlayerService(defaults: defaults)
        player.restorePlaybackSessionIfAvailable()
        XCTAssertNil(player.currentTrack)
        XCTAssertEqual(player.repeatMode, .all)
        player.isShuffle = true
        player.savePlaybackSession()
        XCTAssertEqual(PlaybackSession.load(from: defaults)?.position, 3)
        XCTAssertEqual(PlaybackSession.load(from: defaults)?.abRepeat, .looping(2..<4))

        try FileManager.default.moveItem(at: offline, to: url)
        player.fallbackTracksProvider = { [track] }
        player.restorePlaybackSessionIfAvailable()
        XCTAssertEqual(player.currentTrack?.id, track.id)
        XCTAssertEqual(player.currentTime, 3)
        XCTAssertEqual(player.abRepeat, .looping(2..<4))
        XCTAssertFalse(player.isPlaying)
    }

    @MainActor
    func testChoosingAnotherTrackSupersedesUnavailableSession() throws {
        let track = try makeTrack()
        var missing = track
        missing.fullPath = directory.appendingPathComponent("missing.caf").path
        PlaybackSession(track: missing, position: 8, isShuffle: false, repeatMode: .off,
                        abRepeat: .looping(7..<10)).save(to: defaults)
        let player = AudioPlayerService(defaults: defaults)
        player.restorePlaybackSessionIfAvailable()
        player.play(track: track, in: [track])
        try FileManager.default.copyItem(atPath: track.fullPath, toPath: missing.fullPath)
        player.restorePlaybackSessionIfAvailable()
        XCTAssertEqual(player.currentTrack?.id, track.id)
        XCTAssertEqual(PlaybackSession.load(from: defaults)?.track?.id, track.id)
        XCTAssertEqual(PlaybackSession.load(from: defaults)?.abRepeat, .off)
        XCTAssertEqual(player.currentTime, 0)
    }

    private func makeTrack() throws -> Track {
        let url = directory.appendingPathComponent("test.caf")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 1))
        let audio = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96000))
        audio.frameLength = audio.frameCapacity
        try XCTUnwrap(audio.floatChannelData?[0]).update(repeating: 0, count: Int(audio.frameLength))
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: audio)
        return Track(filename: url.lastPathComponent, relativePath: url.lastPathComponent, fullPath: url.path,
                     format: "CAF", title: "Test", artist: "", album: "", trackNum: "", year: "", genre: "",
                     durationSeconds: 12, bitrateKbps: 256, sampleRate: 8000, bitsPerSample: 32,
                     hasArtwork: false, sizeBytes: Int64(audio.frameLength) * 4)
    }
}
