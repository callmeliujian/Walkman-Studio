import SwiftUI
import AppKit

struct FullScreenVolumeSlider: View {
    @ObservedObject private var localization = AppLocalization.shared
    @Binding var volume: Float
    let totalWidth: CGFloat = 96
    let trackHeight: CGFloat = 6.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let clampedVol = CGFloat(max(0.0, min(1.0, volume)))
            let fillWidth = max(0, w * clampedVol)

            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.white.opacity(0.26))
                    .frame(height: trackHeight)

                // Filled Active Level Track
                Rectangle()
                    .fill(Color.white)
                    .frame(width: fillWidth, height: trackHeight)
            }
            .frame(height: trackHeight)
            .clipShape(Capsule())
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newPct = Float(max(0.0, min(1.0, value.location.x / w)))
                        volume = newPct
                    }
            )
        }
        .frame(width: totalWidth, height: 26)
        .onHover { h in
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
