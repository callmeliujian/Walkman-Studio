import SwiftUI

struct ABRepeatButton: View {
    @ObservedObject var player: AudioPlayerService
    @ObservedObject private var progress: PlaybackProgress

    init(player: AudioPlayerService) {
        self.player = player
        self.progress = player.progress
    }

    private var label: String {
        switch player.abRepeat {
        case .off: return "A–B"
        case .startMarked: return L10n.tr("Set B")
        case .looping: return "A↔B"
        }
    }

    private func timestamp(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1, fractionalSecondsLength: 1)))
    }

    private var helpText: String {
        switch player.abRepeat {
        case .off:
            return L10n.tr("Set A at the current position")
        case .startMarked(let start):
            return L10n.tr("A at \(timestamp(start)). Move at least 0.1 s past A and click to set B.")
        case .looping(let range):
            return L10n.tr("Repeating \(timestamp(range.lowerBound)) to \(timestamp(range.upperBound)). Click to clear.")
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Button(action: player.advanceABRepeat) {
                Text(verbatim: label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 5)
                    .frame(minWidth: 30, minHeight: 19)
                    .background(Capsule().fill(.primary.opacity(player.abRepeat == .off ? 0.06 : 0.12)))
                    .contentShape(Capsule())
            }
            .disabled(player.currentTrack == nil || !player.abRepeat.canAdvance(at: progress.currentTime, duration: progress.duration))
            .help(helpText)
            .accessibilityLabel(helpText)

            if case .startMarked = player.abRepeat {
                Button(action: player.clearABRepeat) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .frame(width: 18, height: 19)
                        .contentShape(Rectangle())
                }
                .help(L10n.tr("Clear A–B markers"))
                .accessibilityLabel(L10n.tr("Clear A–B markers"))
            }
        }
        .fixedSize()
        .foregroundStyle(player.abRepeat == .off ? WalkmanTheme.silverMuted : WalkmanTheme.hiResGoldLight)
        .buttonStyle(.plain)
    }
}
