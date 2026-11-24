import SwiftUI

// MARK: - Active & Hover Mode Pill Backgrounds (Liquid Glass Sliding Lens)
struct ActiveModePillBackground: View {
    @ObservedObject private var localization = AppLocalization.shared
    let isGold: Bool
    var isHovered: Bool = false

    var body: some View {
        ZStack {
            // Translucent Body Fill
            if isGold {
                WalkmanTheme.hiResGold.opacity(isHovered ? 0.24 : 0.18)
            } else {
                Color.white.opacity(isHovered ? 0.20 : 0.16)
            }

            // Top specular refraction sheen
            VStack(spacing: 0) {
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(isHovered ? 0.42 : 0.35), location: 0.0),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 6)
                Spacer(minLength: 0)
            }
        }
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    isGold ?
                        WalkmanTheme.hiResGold.opacity(isHovered ? 0.70 : 0.55) :
                        Color.white.opacity(isHovered ? 0.45 : 0.34),
                    lineWidth: 0.85
                )
        )
        .shadow(
            color: Color.black.opacity(isHovered ? 0.30 : 0.22),
            radius: isHovered ? 4 : 2.5,
            x: 0,
            y: 1
        )
    }
}
