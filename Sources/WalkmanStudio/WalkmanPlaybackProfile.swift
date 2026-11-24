import Foundation

struct WalkmanPlaybackProfile: Sendable {
    let name: String
    let rules: [WalkmanAudioRule]
    var hasDeclaredFormats = true

    static func load(for target: WalkmanDrive, drives: [WalkmanDrive]) -> Self? {
        guard target.type != .local else { return nil }
        var volumes = [target]
        if target.type == .microsd,
           let pair = WalkmanDeviceDetector.shared.detectDevices(drives: drives).first(where: { $0.drives.contains(target) }),
           let player = pair.drives.first(where: { $0.type == .internal }) {
            volumes.append(player)
        }
        var model: String?
        for volume in volumes {
            let root = URL(fileURLWithPath: volume.mountPoint)
            for filename in ["capability_00.xml", "default-capability.xml", "DEFAULT-CAPABILITY.XML"] {
                guard let data = try? Data(contentsOf: root.appendingPathComponent(filename)),
                      let doc = try? XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever]) else { continue }
                let names = try? doc.nodes(forXPath: "//*[local-name()='Model' or local-name()='model']")
                model = names?.first?.stringValue ?? model
                let rules = audioRules(in: doc)
                if !rules.isEmpty { return Self(name: model ?? target.name, rules: rules) }
            }
        }
        let name = model ?? volumes.last?.name ?? target.name
        let compact = name.uppercased().replacingOccurrences(of: "-", with: "")
        var rules = [formatRule("mp3")]
        if WalkmanDeviceDetector.isAndroidModel(modelRaw: name) || compact.range(of: #"NWZ?(ZX[0-9]+|WM1[A-Z]|A[1-5][0567])([^0-9]|$)"#, options: .regularExpression) != nil {
            rules = ["mp3", "flac", "wav", "aac", "alac", "aiff", "dsd", "ape", "wma"].map(formatRule)
            if WalkmanDeviceDetector.isAndroidModel(modelRaw: name) { rules += [formatRule("ogg"), formatRule("opus")] }
        }
        return Self(name: name, rules: rules, hasDeclaredFormats: false)
    }

    private static func formatRule(_ id: String) -> WalkmanAudioRule {
        switch id.lowercased() {
        case "aac", "aac_lc", "he-aac": return WalkmanAudioRule(extensions: ["aac", "mp4", "m4a", "3gp"], codecs: ["aac", "he-aac"])
        case "alac": return WalkmanAudioRule(extensions: ["alac", "m4a", "mp4"], codecs: ["alac"])
        case "lpcm", "pcm", "wav": return WalkmanAudioRule(extensions: ["wav"], codecs: ["lpcm"])
        case "aiff": return WalkmanAudioRule(extensions: ["aiff", "aif"])
        case "dsd": return WalkmanAudioRule(extensions: ["dsf", "dff"])
        case "mp3", "flac": return WalkmanAudioRule(extensions: [id], codecs: [id])
        default: return WalkmanAudioRule(extensions: [id.lowercased()])
        }
    }

    private static func audioRules(in doc: XMLDocument) -> [WalkmanAudioRule] {
        let path = "//*[local-name()='PlaybackCapabilities' and not(@target)]/*[local-name()='Audio']"
        let nodes = (try? doc.nodes(forXPath: path)) ?? []
        var rules: [WalkmanAudioRule] = []
        for audio in nodes {
            func values(_ parent: XMLNode, _ path: String) -> [String] {
                ((try? parent.nodes(forXPath: path)) ?? []).compactMap { $0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            }
            func limits(_ key: String) -> Set<Int> {
                Set(values(audio, "./*[local-name()='AudioCapability']/*[local-name()='\(key)']").compactMap(Int.init))
            }
            for format in (try? audio.nodes(forXPath: "./*[local-name()='Format']")) ?? [] {
                let extensions = Set(values(format, "./*[local-name()='Extension']"))
                guard !extensions.isEmpty else { continue }
                var codecs = Set(values(format, ".//*[local-name()='Codec']").map { codec in
                    if codec == "aac_lc" { return "aac" }
                    if codec.hasPrefix("he-aac") { return "he-aac" }
                    return codec
                })
                if codecs.isEmpty, extensions == ["wav"] { codecs = ["lpcm"] }
                rules.append(WalkmanAudioRule(extensions: extensions, codecs: codecs, rates: limits("SamplingRate"), bits: limits("QuantizationBit"), channels: limits("Channel"), maxBitrate: limits("MaxBitrate").max() ?? 0))
            }
        }
        if !rules.isEmpty { return rules }
        // Some default-capability manifests identify audio formats by ID.
        let formats = (try? doc.nodes(forXPath: "//*[local-name()='audio' or local-name()='Audio']//*[local-name()='format' or local-name()='Format']/@id")) ?? []
        return formats.compactMap { $0.stringValue?.lowercased() }.map(formatRule)
    }

    func accepts(_ audio: TransferAudioFormat) -> Bool { rules.contains { $0.accepts(audio) } }

    func canPlay(_ url: URL) -> Bool {
        guard rules.contains(where: { $0.extensions.contains(url.pathExtension.lowercased()) }) else { return false }
        return accepts(.read(url))
    }

    /// Keep an unplayable file at the requested path, including same-container conversions.
    func destination(for requested: URL) -> URL {
        var url = requested
        var version = 1
        while FileManager.default.fileExists(atPath: url.path), !canPlay(url) {
            version += 1
            let stem = requested.deletingPathExtension().lastPathComponent
            url = requested.deletingLastPathComponent().appendingPathComponent("\(stem) (\(version)).\(requested.pathExtension)")
        }
        return url
    }
}
