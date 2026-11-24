import XCTest
@testable import WalkmanStudio

final class TransferCompatibilityTests: XCTestCase {
    private var root: URL!
    private var drive: WalkmanDrive!
    private var ffmpeg: URL?

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let device = root.appendingPathComponent("WALKMAN")
        let music = device.appendingPathComponent("MUSIC")
        try FileManager.default.createDirectory(at: music, withIntermediateDirectories: true)
        drive = WalkmanDrive(name: "WALKMAN", mountPoint: device.path, type: .internal, totalBytes: 0,
                             usedBytes: 0, freeBytes: 0, percentUsed: 0, hasCfw: false, musicDir: music.path)
        let xml = """
        <Devices xmlns="http://xmlns.sony.net/walkman/capability"><Device><Identification><Model>NW-S750 Series</Model></Identification>
        <PlaybackCapabilities><Audio><Format><Extension>mp3</Extension><Encoding><Codec>MP3</Codec></Encoding></Format></Audio>
        <Audio><Format><Extension>m4a</Extension><Encoding><Codec>AAC_LC</Codec></Encoding></Format></Audio>
        <Audio><Format><Extension>wav</Extension></Format><AudioCapability><Channel>2</Channel><SamplingRate>44100</SamplingRate><QuantizationBit>16</QuantizationBit></AudioCapability></Audio>
        <Video><Format><Extension>flac</Extension></Format></Video></PlaybackCapabilities>
        <PlaybackCapabilities target="feedsound"><Audio><Format><Extension>flac</Extension></Format></Audio></PlaybackCapabilities></Device></Devices>
        """
        try xml.write(to: device.appendingPathComponent("capability_00.xml"), atomically: true, encoding: .utf8)
        ffmpeg = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"].first { FileManager.default.isExecutableFile(atPath: $0) }.map(URL.init(fileURLWithPath:))
    }

    override func tearDownWithError() throws {
        if let root { try FileManager.default.removeItem(at: root) }
    }

    private func track(_ name: String, codec: String, rate: Int = 44100, duration: Double = 0.2) throws -> Track {
        let file = root.appendingPathComponent(name)
        let encoder = try XCTUnwrap(ffmpeg, "FFmpeg is required to exercise actual transfers")
        let p = Process()
        p.executableURL = encoder
        p.arguments = ["-v", "error", "-f", "lavfi", "-i", "sine=duration=\(duration)", "-ac", "2", "-ar", String(rate), "-c:a", codec, file.path]
        try p.run()
        p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0)
        return TransferItem(sourceURL: file, title: file.deletingPathExtension().lastPathComponent, artist: "Singer", album: "Album").toPreviewTrack()
    }

    func testDeviceAndQueuePresetCheckContainerCodecAndResolution() throws {
        try XCTSkipIf(ffmpeg == nil, "FFmpeg not installed")
        let flac = try track("Lossless.flac", codec: "flac")
        let aac = try track("AAC.m4a", codec: "aac")
        let alac = try track("Apple Lossless.m4a", codec: "alac")
        let wav = try track("CD.wav", codec: "pcm_s16le")
        let high = try track("High.wav", codec: "pcm_s24le", rate: 96000)
        let tracks = [flac, aac, alac, wav, high]
        let plan = TransferCompatibilityPlan(tracks: tracks, target: drive, drives: [drive])
        XCTAssertEqual(plan.profile?.name, "NW-S750 Series")
        XCTAssertEqual(plan.affected.map(\.title), [flac, alac, high].map(\.title))
        XCTAssertTrue(plan.choices.contains("mp3_320"))
        XCTAssertTrue(plan.choices.contains("wav_16"))
        XCTAssertFalse(plan.choices.contains("alac_16"))
        XCTAssertFalse(plan.choices.contains("flac_16"))
        XCTAssertEqual(plan.preset(for: URL(fileURLWithPath: wav.fullPath), selection: "mp3_320"), "copy_raw")
        let queue = TransferCompatibilityPlan(tracks: [aac, wav], target: drive, drives: [drive], requestedPreset: "flac_16")
        XCTAssertEqual(queue.affected.count, 2)
        let local = TransferCompatibilityPlan(tracks: tracks, target: .localLibrary(at: root), drives: [drive])
        XCTAssertTrue(local.affected.isEmpty)
    }

    @MainActor
    func testConfirmedMixedTransferPreservesOldUnplayableCopyAndSkipsPlayableCopyOnRetry() async throws {
        try XCTSkipIf(ffmpeg == nil, "FFmpeg not installed")
        let high = try track("Wish.wav", codec: "pcm_s24le", rate: 96000)
        let mp3 = try track("Second.mp3", codec: "libmp3lame")
        let existing = URL(fileURLWithPath: drive.musicDir).appendingPathComponent("Singer/Album/01 - Wish.wav")
        try FileManager.default.createDirectory(at: existing.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: high.fullPath), to: existing)
        let before = try Data(contentsOf: existing)
        let plan = TransferCompatibilityPlan(tracks: [high, mp3], target: drive, drives: [drive])
        do {
            _ = try await TransferQueueService.shared.transferWithResult(plan: plan) { _, _, _ in }
            XCTFail("Conversion requires confirmation")
        } catch {
            XCTAssertEqual((error as NSError).domain, "WalkmanStudio.Transfer")
        }
        var events: [AudioConversionProgress] = []
        let result = try await TransferQueueService.shared.transferWithResult(
            plan: plan, conversion: "wav_16", onConversionProgress: { events.append($0) }
        ) { _, _, _ in }
        XCTAssertEqual(result.transferred, 2)
        XCTAssertEqual(events.first?.fraction, 0)
        XCTAssertEqual(events.last?.fraction, 1)
        XCTAssertEqual(events.filter(\.isComplete).count, 1)
        XCTAssertTrue(events.dropLast().allSatisfy { ($0.fraction ?? 1) < 1 })
        let converted = existing.deletingLastPathComponent().appendingPathComponent("01 - Wish (2).wav")
        XCTAssertEqual(TransferAudioFormat.read(converted).bits, 16)
        XCTAssertEqual(TransferAudioFormat.read(converted).rate, 44100)
        XCTAssertEqual(try Data(contentsOf: existing), before)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: high.fullPath)), before)
        let retry = try await TransferQueueService.shared.transferWithResult(
            plan: plan, conversion: "wav_16", onConversionProgress: { _ in XCTFail("Skipped tracks must not report conversion") }
        ) { _, _, _ in }
        XCTAssertEqual(retry.transferred, 0)
        XCTAssertEqual(retry.duplicates, 2)
    }

    @MainActor
    func testCancellationDuringEncodingDoesNotPublishOutputOrReportCompletion() async throws {
        try XCTSkipIf(ffmpeg == nil, "FFmpeg not installed")
        let source = try track("Long.flac", codec: "flac", duration: 180)
        let dest = root.appendingPathComponent("Cancelled.mp3")
        var events: [AudioConversionProgress] = []
        let task = Task {
            try await WalkmanEngine.shared.transcodeAudio(
                sourceURL: URL(fileURLWithPath: source.fullPath), destinationURL: dest, preset: "mp3_320"
            ) { event in
                events.append(event)
                if event.processedSeconds > 0 && !event.isComplete {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }
        }
        do {
            try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        XCTAssertTrue(events.contains { $0.processedSeconds > 0 })
        XCTAssertFalse(events.contains(where: \.isComplete))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest.path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".walkman-convert-") })
    }

    func testSizePreviewUsesDiskSizeAndOnlyTotalsTracksBeingConverted() throws {
        try XCTSkipIf(ffmpeg == nil, "FFmpeg not installed")
        var first = try track("First.flac", codec: "flac")
        var second = try track("Second.flac", codec: "flac")
        let playable = try track("Playable.mp3", codec: "libmp3lame")
        XCTAssertEqual(first.durationSeconds, 0)
        XCTAssertEqual(try XCTUnwrap(TransferSizeEstimate(track: first).duration), 0.2, accuracy: 0.01)
        first.durationSeconds = 10
        second.durationSeconds = 20
        let plan = TransferCompatibilityPlan(tracks: [first, playable, second], target: drive, drives: [drive])
        let size = try XCTUnwrap(plan.sizesByPath[first.fullPath])
        let fileBytes = try Data(contentsOf: URL(fileURLWithPath: first.fullPath)).count
        XCTAssertEqual(size.originalBytes, Int64(fileBytes))
        XCTAssertNil(plan.sizesByPath[playable.fullPath])
        let secondBytes = try Data(contentsOf: URL(fileURLWithPath: second.fullPath)).count
        XCTAssertEqual(plan.totalSize.originalBytes, Int64(fileBytes + secondBytes))
        XCTAssertEqual(size.convertedBytes(for: "mp3_320"), 400_000...400_000)
        XCTAssertEqual(plan.totalSize.convertedBytes(for: "mp3_320"), 1_200_000...1_200_000)
        XCTAssertEqual(plan.totalSize.convertedBytes(for: "aac_128"), 480_000...480_000)
        XCTAssertEqual(size.convertedBytes(for: "wav_16"), 1_764_000...1_764_000)
        for preset in ["alac_16", "flac_16"] {
            XCTAssertEqual(size.convertedBytes(for: preset), 882_000...1_323_000)
        }
    }

    func testMissingDurationKeepsOriginalSizeAndDoesNotShowAPartialTotal() throws {
        let url = root.appendingPathComponent("Unreadable.flac")
        try Data([1, 2, 3]).write(to: url)
        var track = TransferItem(sourceURL: url).toPreviewTrack()
        let unknown = TransferSizeEstimate(track: track)
        XCTAssertEqual(unknown.originalBytes, 3)
        XCTAssertNil(unknown.convertedBytes(for: "mp3_320"))
        track.durationSeconds = 60
        let total = TransferSizeEstimate(totalOf: [unknown, TransferSizeEstimate(track: track)])
        XCTAssertEqual(total.originalBytes, 6)
        XCTAssertNil(total.convertedBytes(for: "wav_16"))
    }
}
