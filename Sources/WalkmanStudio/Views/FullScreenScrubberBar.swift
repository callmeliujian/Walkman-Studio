import SwiftUI
import AppKit

struct FullScreenScrubberBar: View {
    @ObservedObject private var localization = AppLocalization.shared
    @Binding var currentTime: Double
    let duration: Double
    let abRepeat: ABRepeatState
    let isHiRes: Bool
    let isEnabled: Bool
    let onSeek: (Double) -> Void

    @State private var dragValue: Double? = nil
    @State private var isHovering: Bool = false

    private var activeTime: Double {
        dragValue ?? currentTime
    }

    private var progressRatio: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(max(0, min(1, activeTime / duration)))
    }

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

    private func formatRemaining(_ current: Double, duration: Double) -> String {
        if duration <= 0 || duration.isNaN || duration.isInfinite { return "--:--" }
        let rem = max(0.0, duration - current)
        return "-\(formatTime(rem))"
    }

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { geo in
                let w = geo.size.width
                let thumbX = w * progressRatio
                let trackHeight: CGFloat = isHovering ? 5.5 : 4.0

                ZStack(alignment: .leading) {
                    // Base background track
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: trackHeight)

                    // Active progress fill
                    Capsule()
                        .fill(isHiRes ? WalkmanTheme.hiResGold : Color.white)
                        .frame(width: max(0, min(w, thumbX)), height: trackHeight)

                    ABRepeatMarkers(state: abRepeat, duration: duration)

                    // Smooth tracking thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: isHovering ? 13 : 10, height: isHovering ? 13 : 10)
                        .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1)
                        .offset(x: max(0, min(w - (isHovering ? 13 : 10), thumbX - (isHovering ? 6.5 : 5.0))))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard isEnabled, duration > 0 else { return }
                            let ratio = max(0, min(1, gesture.location.x / w))
                            dragValue = Double(ratio) * duration
                        }
                        .onEnded { gesture in
                            guard isEnabled, duration > 0 else { return }
                            let ratio = max(0, min(1, gesture.location.x / w))
                            let target = Double(ratio) * duration
                            onSeek(target)
                            dragValue = nil
                        }
                )
            }
            .frame(height: 14)
            .onHover { h in
                guard isEnabled else { return }
                isHovering = h
                if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }

            // Timeline elapsed and remaining counters
            HStack {
                Text(isEnabled ? formatTime(activeTime) : "--:--")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(WalkmanTheme.silverMuted)

                Spacer()

                Text(isEnabled ? formatRemaining(activeTime, duration: duration) : "--:--")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(WalkmanTheme.silverMuted)
            }
        }
    }
}
