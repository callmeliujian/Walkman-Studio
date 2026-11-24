import SwiftUI

struct TrackScrubberRow: View {
    @ObservedObject private var localization = AppLocalization.shared
    @ObservedObject var progress = AudioPlayerService.shared.progress
    let isHiRes: Bool
    let onSeek: (Double) -> Void
    let onSeekingChanged: (Bool) -> Void

    @State private var dragTime: Double? = nil

    private func formatTime(_ seconds: Double) -> String {
        if seconds.isNaN || seconds.isInfinite || seconds < 0 { return "0:00" }
        let totalSecs = Int(seconds)
        let hours = totalSecs / 3600
        let mins = (totalSecs % 3600) / 60
        let secs = totalSecs % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }

    var body: some View {
        let curTime = dragTime ?? progress.currentTime
        let durTime = progress.duration
        let timeWidth: CGFloat = durTime >= 3600 ? 54 : (durTime >= 600 ? 40 : 34)

        HStack(spacing: 6) {
            Text(formatTime(curTime))
                .font(WalkmanFont.monoSmall)
                .foregroundStyle(.secondary)
                .frame(width: timeWidth, alignment: .trailing)
                .fixedSize(horizontal: true, vertical: false)

            Slider(
                value: Binding(
                    get: { dragTime ?? progress.currentTime },
                    set: { newTime in dragTime = newTime }
                ),
                in: 0...max(1.0, progress.duration),
                onEditingChanged: { editing in
                    onSeekingChanged(editing)
                    if !editing {
                        if let target = dragTime {
                            onSeek(target)
                        }
                        dragTime = nil
                    }
                }
            )
            .controlSize(.mini)
            .tint(isHiRes ? WalkmanTheme.hiResGold : WalkmanTheme.silver)

            Text(formatTime(durTime))
                .font(WalkmanFont.monoSmall)
                .foregroundStyle(.secondary)
                .frame(width: timeWidth, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}
