import SwiftUI
import AppKit

struct QueueRowView: View {
    @ObservedObject private var localization = AppLocalization.shared
    let index: Int
    let item: Track
    let isCurrent: Bool
    let isPlaying: Bool
    let onPlay: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 14) {
                if isCurrent && isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WalkmanTheme.hiResGold)
                        .frame(width: 24)
                } else {
                    Text("\(index + 1)")
                        .font(WalkmanFont.monoSmall)
                        .foregroundStyle(isCurrent ? WalkmanTheme.hiResGold : WalkmanTheme.silverMuted.opacity(0.6))
                        .frame(width: 24, alignment: .trailing)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 13.5, weight: isCurrent ? .bold : .medium))
                        .foregroundStyle(isCurrent ? WalkmanTheme.hiResGoldLight : .white)
                        .lineLimit(1)

                    Text(item.artist)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(WalkmanTheme.silverMuted)
                        .lineLimit(1)
                }

                Spacer()

                Text(FullScreenNowPlayingView.formatTime(item.durationSeconds))
                    .font(WalkmanFont.monoSmall)
                    .foregroundStyle(WalkmanTheme.silverMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                isCurrent ?
                Color.white.opacity(0.09) :
                (isHovered ? Color.white.opacity(0.04) : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { h in
            isHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
