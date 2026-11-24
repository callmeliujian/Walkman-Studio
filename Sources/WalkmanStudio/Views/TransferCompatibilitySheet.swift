import SwiftUI

struct TransferCompatibilitySheet: View {
    let plan: TransferCompatibilityPlan
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    @State private var selection: String

    init(plan: TransferCompatibilityPlan, onConfirm: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.plan = plan
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _selection = State(initialValue: plan.choices.contains(plan.requestedPreset) ? plan.requestedPreset : plan.choices.first ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.tr("Choose a compatible audio format")).font(.title2.bold())
            if plan.profile?.hasDeclaredFormats == false {
                Text(L10n.tr("\(plan.profile?.name ?? plan.target.name) did not list its playback formats. Choose a compatible copy for these \(plan.affected.count) tracks."))
            } else {
                Text(L10n.tr("\(plan.affected.count) tracks need a different format for \(plan.profile?.name ?? plan.target.name)."))
            }
            if plan.choices.isEmpty {
                Text(L10n.tr("This device lists no compatible conversion preset.")).foregroundStyle(.secondary)
            } else {
                Picker(L10n.tr("Convert these tracks to"), selection: $selection) {
                    ForEach(plan.choices, id: \.self) { preset in
                        Text(Self.label(preset)).tag(preset)
                    }
                }
            }
            List(plan.affected) { track in
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title.isEmpty ? track.filename : track.title).lineLimit(1)
                    Text([track.artist, track.filename].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    if let size = plan.sizesByPath[track.fullPath] {
                        Text(sizeComparison(size)).font(.callout).monospacedDigit()
                    }
                }
                .padding(.vertical, 3)
            }
            .frame(minHeight: 90, maxHeight: 230)
            if plan.affected.count > 1 {
                LabeledContent(L10n.tr("Total Size"), value: sizeComparison(plan.totalSize))
                    .monospacedDigit()
            }
            if !selection.isEmpty {
                Text(L10n.tr("Actual file sizes may vary with compression, artwork and tags."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button(L10n.tr("Cancel"), action: onCancel).keyboardShortcut(.cancelAction)
                Button(L10n.tr("Convert and Transfer")) { onConfirm(selection) }
                    .keyboardShortcut(.defaultAction).disabled(selection.isEmpty)
            }
        }
        .padding(24).frame(width: 510)
    }

    private func sizeComparison(_ size: TransferSizeEstimate) -> String {
        func formatted(_ bytes: Int64) -> String {
            ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
        let original = size.originalBytes.map(formatted) ?? L10n.tr("Size unknown")
        guard let range = size.convertedBytes(for: selection) else {
            return L10n.tr("Original \(original) → Estimate unavailable")
        }
        let lower = formatted(range.lowerBound)
        let upper = formatted(range.upperBound)
        let estimate = lower == upper ? lower : "\(lower)–\(upper)"
        return L10n.tr("Original \(original) → Estimated \(estimate)")
    }

    private static func label(_ preset: String) -> String {
        switch preset {
        case "mp3_320": return "MP3 · 320 kbps"
        case "mp3_128": return "MP3 · 128 kbps"
        case "aac_256": return "AAC (M4A) · 256 kbps"
        case "aac_128": return "AAC (M4A) · 128 kbps"
        case "flac_16": return "FLAC · 16 bit / 44.1 kHz"
        case "alac_16": return "ALAC (M4A) · 16 bit / 44.1 kHz"
        default: return "WAV (PCM) · 16 bit / 44.1 kHz"
        }
    }
}
