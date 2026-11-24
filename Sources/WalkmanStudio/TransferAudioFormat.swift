import AudioToolbox
import Foundation

/// Encoded stream properties, before Core Audio converts samples for playback.
struct TransferAudioFormat: Sendable {
    var ext: String
    var codec: String
    var rate = 0
    var bits = 0
    var channels = 0
    var bitrate = 0
    var durationSeconds: Double = 0

    static func read(_ url: URL) -> Self {
        let ext = url.pathExtension.lowercased()
        var result = Self(ext: ext, codec: ext)
        var file: AudioFileID?
        if AudioFileOpenURL(url as CFURL, .readPermission, 0, &file) == noErr, let file {
            defer { AudioFileClose(file) }
            var desc = AudioStreamBasicDescription()
            var size = UInt32(MemoryLayout.size(ofValue: desc))
            if AudioFileGetProperty(file, kAudioFilePropertyDataFormat, &size, &desc) == noErr {
                result.rate = Int(desc.mSampleRate)
                result.bits = Int(desc.mBitsPerChannel)
                result.channels = Int(desc.mChannelsPerFrame)
                let id = desc.mFormatID
                switch id {
                case kAudioFormatMPEG4AAC: result.codec = "aac"
                case kAudioFormatMPEG4AAC_HE, kAudioFormatMPEG4AAC_HE_V2: result.codec = "he-aac"
                case kAudioFormatAppleLossless: result.codec = "alac"
                case kAudioFormatLinearPCM: result.codec = desc.mFormatFlags & kAudioFormatFlagIsFloat == 0 ? "lpcm" : "float"
                case kAudioFormatMPEGLayer3: result.codec = "mp3"
                case kAudioFormatFLAC: result.codec = "flac"
                default:
                    let bytes = withUnsafeBytes(of: id.bigEndian) { Array($0) }
                    result.codec = String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespaces)
                }
                var bitrate: UInt32 = 0
                size = UInt32(MemoryLayout.size(ofValue: bitrate))
                if AudioFileGetProperty(file, kAudioFilePropertyBitRate, &size, &bitrate) == noErr {
                    result.bitrate = Int(bitrate)
                }
                var seconds: Double = 0
                size = UInt32(MemoryLayout.size(ofValue: seconds))
                if AudioFileGetProperty(file, kAudioFilePropertyEstimatedDuration, &size, &seconds) == noErr {
                    result.durationSeconds = seconds
                }
                return result
            }
        }
        // Core Audio cannot inspect some Walkman formats (including WMA and DSD).
        let probe = Process()
        let path = ["/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe"].first { FileManager.default.isExecutableFile(atPath: $0) }
        guard let path else { return result }
        probe.executableURL = URL(fileURLWithPath: path)
        probe.arguments = ["-v", "error", "-select_streams", "a:0", "-show_entries", "stream=codec_name,profile,sample_rate,channels,bits_per_raw_sample,bits_per_sample,bit_rate:format=duration", "-of", "json", url.path]
        let pipe = Pipe()
        probe.standardOutput = pipe
        probe.standardError = FileHandle.nullDevice
        guard (try? probe.run()) != nil else { return result }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        probe.waitUntilExit()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stream = (json["streams"] as? [[String: Any]])?.first else { return result }
        func number(_ key: String) -> Int { Int(stream[key] as? String ?? "") ?? stream[key] as? Int ?? 0 }
        if let codec = stream["codec_name"] as? String {
            if codec.hasPrefix("pcm_s") || codec.hasPrefix("pcm_u") { result.codec = "lpcm" }
            else if codec == "wmav1" || codec == "wmav2" { result.codec = "wma" }
            else if codec == "aac", (stream["profile"] as? String)?.hasPrefix("HE") == true { result.codec = "he-aac" }
            else { result.codec = codec }
        }
        result.rate = number("sample_rate")
        result.channels = number("channels")
        result.bits = max(number("bits_per_raw_sample"), number("bits_per_sample"))
        result.bitrate = number("bit_rate")
        if let format = json["format"] as? [String: Any], let seconds = format["duration"] as? String {
            result.durationSeconds = Double(seconds) ?? 0
        }
        return result
    }

    static func output(preset: String, source: Self, stereoCD: Bool = false) -> Self {
        let parts = preset.split(separator: "_")
        let family = parts.first.map(String.init) ?? ""
        var output = source
        switch family {
        case "copy":
            if source.ext == "m4b" { output.ext = "m4a" }
            return output
        case "mp3", "aac":
            output.ext = family == "aac" ? "m4a" : family
            output.codec = family
            output.bits = 0
            output.bitrate = (Int(parts.last ?? "") ?? 320) * 1000
        case "alac":
            output = Self(ext: "m4a", codec: "alac", rate: source.rate, bits: 16, channels: source.channels)
        case "wav": output = Self(ext: "wav", codec: "lpcm", rate: 44100, bits: 16, channels: source.channels)
        case "flac":
            let rates = ["flac_16": 44100, "flac_24_48": 48000, "flac_24_192": 192000]
            output = Self(ext: "flac", codec: "flac", rate: rates[preset] ?? 96000, bits: preset == "flac_16" ? 16 : 24, channels: source.channels)
        default: return source
        }
        if stereoCD {
            output.channels = 2
            output.rate = 44100
        }
        if output.codec == "lpcm" { output.bitrate = output.rate * output.bits * output.channels }
        return output
    }
}
