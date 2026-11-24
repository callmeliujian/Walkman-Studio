import SwiftUI

struct HoverModePillBackground: View {
    @ObservedObject private var localization = AppLocalization.shared
    var body: some View {
        ZStack {
            Color.white.opacity(0.09)
            VStack(spacing: 0) {
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.20), location: 0.0),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 5.5)
                Spacer(minLength: 0)
            }
        }
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.85)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}
