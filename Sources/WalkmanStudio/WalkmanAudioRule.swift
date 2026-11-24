import Foundation

struct WalkmanAudioRule: Sendable {
    var extensions: Set<String>
    var codecs: Set<String> = []
    var rates: Set<Int> = []
    var bits: Set<Int> = []
    var channels: Set<Int> = []
    var maxBitrate = 0

    func accepts(_ audio: TransferAudioFormat) -> Bool {
        extensions.contains(audio.ext) && (codecs.isEmpty || codecs.contains(audio.codec))
            && (rates.isEmpty || rates.contains(audio.rate))
            && (bits.isEmpty || bits.contains(audio.bits))
            && (channels.isEmpty || channels.contains(audio.channels))
            && (maxBitrate == 0 || (audio.bitrate > 0 && audio.bitrate <= maxBitrate))
    }
}
