import Foundation

struct TransferCompatibilityPlan: Identifiable, Sendable {
    let id = UUID()
    let target: WalkmanDrive
    let tracks: [Track]
    let profile: WalkmanPlaybackProfile?
    let affected: [Track]
    let affectedPaths: Set<String>
    let sizesByPath: [String: TransferSizeEstimate]
    let totalSize: TransferSizeEstimate
    let choices: [String]
    let requestedPreset: String

    init(tracks: [Track], target: WalkmanDrive, drives: [WalkmanDrive], requestedPreset: String = "copy_raw", remuxAudiobooks: Bool = false) {
        self.target = target
        self.tracks = tracks
        self.requestedPreset = requestedPreset
        let profile = WalkmanPlaybackProfile.load(for: target, drives: drives)
        self.profile = profile
        self.affected = tracks.filter { track in
            guard let profile, FileManager.default.fileExists(atPath: track.fullPath) else { return false }
            let url = URL(fileURLWithPath: track.fullPath)
            let ext = url.pathExtension.lowercased()
            let container = remuxAudiobooks && ext == "m4b" ? "m4a" : ext
            guard profile.rules.contains(where: { $0.extensions.contains(container) }) else { return true }
            var source = TransferAudioFormat.read(url)
            source.ext = container
            return !profile.accepts(source) || !profile.accepts(.output(preset: requestedPreset, source: source))
        }
        self.affectedPaths = Set(affected.map(\.fullPath))
        sizesByPath = affected.reduce(into: [:]) { sizes, track in
            sizes[track.fullPath] = TransferSizeEstimate(track: track)
        }
        totalSize = TransferSizeEstimate(totalOf: sizesByPath.values)
        let presets = ["mp3_320", "aac_256", "wav_16", "flac_16", "alac_16", "mp3_128", "aac_128"]
        self.choices = presets.filter { preset in
            let format = TransferAudioFormat.output(preset: preset, source: .init(ext: "", codec: ""), stereoCD: true)
            return profile?.accepts(format) == true
        }
    }

    func preset(for url: URL, selection: String?) -> String {
        if let selection, affectedPaths.contains(url.path) { return selection }
        return requestedPreset
    }
}
