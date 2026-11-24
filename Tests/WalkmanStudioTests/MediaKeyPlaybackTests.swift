import AppKit
import AVFoundation
import MediaPlayer
import XCTest
@testable import WalkmanStudio

final class MediaKeyPlaybackTests: XCTestCase {
    @MainActor
    func testPlayPauseMediaKeyTogglesOnceThroughRemoteCommand() throws {
        let app = NSApplication.shared
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 1))
        let silence = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8000))
        silence.frameLength = silence.frameCapacity
        try XCTUnwrap(silence.floatChannelData?[0]).update(repeating: 0, count: Int(silence.frameLength))
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: silence)
        let track = Track(filename: url.lastPathComponent, relativePath: url.lastPathComponent, fullPath: url.path,
                          format: "CAF", title: "Media key test", artist: "", album: "", trackNum: "", year: "",
                          genre: "", durationSeconds: 1, bitrateKbps: 256, sampleRate: 8000, bitsPerSample: 32,
                          hasArtwork: false, sizeBytes: 32000)

        let player = AudioPlayerService.shared
        defer { player.stopAndClear() }
        let center = MPNowPlayingInfoCenter.default()
        player.play(track: track, in: [track])
        assertPlayback(isPlaying: true)

        func assertPlayback(isPlaying: Bool, line: UInt = #line) {
            XCTAssertEqual(player.isPlaying, isPlaying, line: line)
            XCTAssertEqual(center.playbackState, isPlaying ? .playing : .paused, line: line)
        }

        func sendPlayKey(flags: Int) throws {
            let event = try XCTUnwrap(NSEvent.otherEvent(
                with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                context: nil, subtype: 8, data1: (Int(NX_KEYTYPE_PLAY) << 16) | flags, data2: 0
            ))
            app.sendEvent(event)
        }

        // First press delivers the AppKit event before the remote command.
        try sendPlayKey(flags: 0x0A00) // Down
        assertPlayback(isPlaying: true)
        XCTAssertEqual(player.handleRemoteTogglePlayPause(), .success)
        assertPlayback(isPlaying: false)
        try sendPlayKey(flags: 0x0A01) // Auto-repeat while held
        assertPlayback(isPlaying: false)
        try sendPlayKey(flags: 0x0B00) // Up
        assertPlayback(isPlaying: false)

        // A second press immediately delivers the same pair in the opposite order.
        XCTAssertEqual(player.handleRemoteTogglePlayPause(), .success)
        assertPlayback(isPlaying: true)
        try sendPlayKey(flags: 0x0A00)
        assertPlayback(isPlaying: true)
        try sendPlayKey(flags: 0x0B00)
        assertPlayback(isPlaying: true)

        // Standard function-key mode delivers F8 as a regular key-down event.
        for isRepeat in [false, true] {
            let f8 = try XCTUnwrap(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: .function, timestamp: 0, windowNumber: 0,
                context: nil, characters: "\u{F70B}", charactersIgnoringModifiers: "\u{F70B}",
                isARepeat: isRepeat, keyCode: 100
            ))
            app.sendEvent(f8)
            assertPlayback(isPlaying: false)
        }

        player.stopAndClear()
        XCTAssertEqual(center.playbackState, .stopped)
        XCTAssertNil(center.nowPlayingInfo)
    }
}
