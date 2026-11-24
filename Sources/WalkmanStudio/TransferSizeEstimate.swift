import Foundation

struct TransferSizeEstimate: Sendable {
    let originalBytes: Int64?
    let duration: Double?

    init(track: Track) {
        let url = URL(fileURLWithPath: track.fullPath)
        let fileBytes = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        originalBytes = fileBytes.map(Int64.init) ?? (track.sizeBytes > 0 ? track.sizeBytes : nil)
        if track.durationSeconds.isFinite, track.durationSeconds > 0 {
            duration = track.durationSeconds
        } else {
            let seconds = TransferAudioFormat.read(url).durationSeconds
            duration = seconds.isFinite && seconds > 0 ? seconds : nil
        }
    }

    init<S: Sequence>(totalOf sizes: S) where S.Element == Self {
        var bytes: Int64? = 0
        var seconds: Double? = 0
        for size in sizes {
            bytes = bytes.flatMap { total in size.originalBytes.map { total + $0 } }
            seconds = seconds.flatMap { total in size.duration.map { total + $0 } }
        }
        originalBytes = bytes
        duration = seconds
    }

    func convertedBytes(for preset: String) -> ClosedRange<Int64>? {
        guard let duration else { return nil }
        let output = TransferAudioFormat.output(preset: preset, source: .init(ext: "", codec: ""), stereoCD: true)
        if output.bitrate > 0, let bytes = Int64(exactly: (duration * Double(output.bitrate) / 8).rounded()) {
            return bytes...bytes
        }
        guard output.codec == "flac" || output.codec == "alac" else { return nil }
        // A typical music estimate. Lossless compression varies with the recording.
        let pcmBytes = duration * Double(output.rate * output.channels * output.bits) / 8
        guard let low = Int64(exactly: (pcmBytes * 0.50).rounded()),
              let high = Int64(exactly: (pcmBytes * 0.75).rounded()) else { return nil }
        return low...high
    }
}
