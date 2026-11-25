import SwiftUI

struct ABRepeatMarkers: View {
    let state: ABRepeatState
    let duration: Double

    var body: some View {
        GeometryReader { geometry in
            if let start = state.start, duration.isFinite, duration > 0 {
                let width = geometry.size.width
                let startX = width * min(1, start / duration)
                Path { path in
                    path.move(to: CGPoint(x: startX, y: 0))
                    path.addLine(to: CGPoint(x: startX, y: 8))
                    if let range = state.range {
                        let endX = width * min(1, range.upperBound / duration)
                        path.move(to: CGPoint(x: startX, y: 4))
                        path.addLine(to: CGPoint(x: endX, y: 4))
                        path.move(to: CGPoint(x: endX, y: 0))
                        path.addLine(to: CGPoint(x: endX, y: 8))
                    }
                }
                .stroke(WalkmanTheme.hiResGoldLight, lineWidth: 2)
            }
        }
        .frame(height: 8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
