import AVFoundation
import Combine
import XCTest
@testable import WalkmanStudio

final class PlaybackRepeatTests: XCTestCase {
    func testButtonCyclesAndShowsSingleTrackSymbol() {
        var mode = PlaybackRepeatMode.off
        for _ in 0..<2 {
            XCTAssertEqual(mode.symbolName, "repeat")
            mode = mode.next
            XCTAssertEqual(mode, .all)
            XCTAssertEqual(mode.symbolName, "repeat")
            mode = mode.next
            XCTAssertEqual(mode, .one)
            XCTAssertEqual(mode.symbolName, "repeat.1")
            mode = mode.next
            XCTAssertEqual(mode, .off)
        }
    }

    @MainActor
    func testNaturalEndsAndManualSkip() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try silentTrack(in: directory, name: "first")
        let last = try silentTrack(in: directory, name: "last")
        let player = AudioPlayerService.shared
        let savedMode = player.repeatMode
        let savedShuffle = player.isShuffle
        let savedProvider = player.activeQueueProvider
        player.activeQueueProvider = { [first, last] }
        defer {
            player.stopAndClear()
            player.repeatMode = savedMode
            player.isShuffle = savedShuffle
            player.activeQueueProvider = savedProvider
        }

        // With shuffle also enabled, observe the same audio file actually reaching its end twice.
        player.isShuffle = true
        player.repeatMode = .one
        let repeated = expectation(description: "First track plays to the end twice")
        repeated.expectedFulfillmentCount = 2
        let ends = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .compactMap { ($0.object as? AVPlayerItem)?.asset as? AVURLAsset }
            .filter { $0.url.path == first.fullPath }
            .prefix(2)
            .sink { _ in repeated.fulfill() }
        defer { ends.cancel() }
        player.play(track: first, in: [first, last])
        await fulfillment(of: [repeated], timeout: 8)
        XCTAssertEqual(player.currentTrack?.id, first.id)

        player.playNext()
        XCTAssertEqual(player.currentTrack?.id, last.id)
        player.isShuffle = false
        player.repeatMode = .all
        let wrapped = expectation(description: "Last track advances to first")
        let tracks = player.$currentTrack.compactMap { $0 }.filter { $0.id == first.id }.prefix(1)
            .sink { _ in wrapped.fulfill() }
        defer { tracks.cancel() }
        await fulfillment(of: [wrapped], timeout: 8)

        player.repeatMode = .off
        let stopped = expectation(description: "Playback stops at the end of the list")
        let playing = player.$isPlaying.filter { !$0 }.prefix(1).sink { _ in stopped.fulfill() }
        defer { playing.cancel() }
        await fulfillment(of: [stopped], timeout: 8)
        XCTAssertEqual(player.currentTrack?.id, last.id)
    }

    @MainActor
    func testABRepeatPlaysToBMultipleTimesThenContinuesThroughTheQueue() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try silentTrack(in: directory, name: "first")
        let next = try silentTrack(in: directory, name: "next")
        let suite = "ABRepeat." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let player = AudioPlayerService(defaults: defaults)
        defer { player.stopAndClear() }

        player.prepare(track: first, in: [first, next], startTime: 0.1)
        player.advanceABRepeat()
        player.seek(to: 0.4)
        player.advanceABRepeat()
        XCTAssertEqual(player.abRepeat, .looping(0.1..<0.4))
        XCTAssertEqual(player.currentTime, 0.1)
        XCTAssertFalse(player.isPlaying)
        player.repeatMode = .one
        player.highlightPreviewDuration = 0.05

        let repeated = expectation(description: "AVPlayer reaches B twice before the file ends")
        repeated.expectedFulfillmentCount = 2
        let ends = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .compactMap { $0.object as? AVPlayerItem }
            .filter { ($0.asset as? AVURLAsset)?.url.path == first.fullPath }
            .prefix(2)
            .sink { item in
                XCTAssertEqual(item.forwardPlaybackEndTime.seconds, 0.4, accuracy: 0.001)
                repeated.fulfill()
            }
        defer { ends.cancel() }
        player.seek(to: 0.3999)
        player.play()
        await fulfillment(of: [repeated], timeout: 6)
        player.pause()
        XCTAssertEqual(player.currentTrack?.id, first.id)
        XCTAssertEqual(player.abRepeat, .looping(0.1..<0.4))

        player.advanceABRepeat()
        XCTAssertEqual(player.abRepeat, .off)
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.repeatMode, .one)
        player.repeatMode = .off
        player.highlightPreviewDuration = nil
        let advanced = expectation(description: "Playback continues past B to the next file")
        let tracks = player.$currentTrack.compactMap { $0 }.first(where: { $0.id == next.id })
            .sink { _ in advanced.fulfill() }
        defer { tracks.cancel() }
        player.play()
        await fulfillment(of: [advanced], timeout: 5)
    }

    @MainActor
    func testABMarkersFollowManualSeeksAndTrackChanges() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try silentTrack(in: directory, name: "first")
        let next = try silentTrack(in: directory, name: "next")
        let suite = "ABRepeat." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let player = AudioPlayerService(defaults: defaults)
        defer { player.stopAndClear() }

        player.advanceABRepeat()
        XCTAssertEqual(player.abRepeat, .off)
        player.prepare(track: first, in: [first, next], startTime: 0.2)
        player.advanceABRepeat()
        player.seek(to: 0.1)
        player.advanceABRepeat()
        XCTAssertEqual(player.abRepeat, .startMarked(0.2))
        player.clearABRepeat()
        XCTAssertEqual(player.abRepeat, .off)

        player.advanceABRepeat()
        player.seek(to: first.durationSeconds)
        player.advanceABRepeat()
        player.seek(to: 0.3)
        XCTAssertEqual(player.abRepeat, .looping(0.1..<0.5))
        player.seek(to: 0)
        XCTAssertEqual(player.abRepeat, .off)
        XCTAssertEqual(player.currentTime, 0)
        player.advanceABRepeat()
        let moving = expectation(description: "The playhead passes A")
        let times = player.progress.$currentTime.first(where: { $0 >= 0.15 })
            .sink { _ in moving.fulfill() }
        defer { times.cancel() }
        player.play()
        await fulfillment(of: [moving], timeout: 5)
        player.advanceABRepeat()
        let range = try XCTUnwrap(player.abRepeat.range)
        XCTAssertEqual(range.lowerBound, 0)
        let looped = expectation(description: "Setting B during playback keeps the loop playing")
        looped.expectedFulfillmentCount = 2
        let ends = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .compactMap { $0.object as? AVPlayerItem }
            .filter { ($0.asset as? AVURLAsset)?.url.path == first.fullPath }
            .prefix(2)
            .sink { _ in looped.fulfill() }
        defer { ends.cancel() }
        await fulfillment(of: [looped], timeout: 5)
        XCTAssertTrue(player.isPlaying)
        player.playNext()
        XCTAssertEqual(player.currentTrack?.id, next.id)
        XCTAssertEqual(player.abRepeat, .off)
        player.advanceABRepeat()
        player.stopAndClear()
        XCTAssertEqual(player.abRepeat, .off)
    }

    private func silentTrack(in directory: URL, name: String) throws -> Track {
        let url = directory.appendingPathComponent(name).appendingPathExtension("caf")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 22050))
        buffer.frameLength = buffer.frameCapacity
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        samples.update(repeating: 0, count: Int(buffer.frameLength))
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
        return Track(filename: url.lastPathComponent, relativePath: url.lastPathComponent, fullPath: url.path,
                     format: "CAF", title: name, artist: "", album: "", trackNum: "", year: "", genre: "",
                     durationSeconds: 0.5, bitrateKbps: 1411, sampleRate: 44100, bitsPerSample: 32,
                     hasArtwork: false, sizeBytes: Int64(buffer.frameLength) * 4)
    }
}
