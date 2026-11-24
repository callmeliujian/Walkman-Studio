import SwiftUI

// MARK: - Indeterminate Liquid Glass Bar
struct IndeterminateLiquidGlassBar: View {
    @ObservedObject private var localization = AppLocalization.shared
    @State private var phase: CGFloat = -0.3

    var body: some View {
        GeometryReader { _ in
            Capsule()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.0), location: max(0.0, phase - 0.2)),
                            .init(color: Color.white.opacity(0.55), location: min(max(0.0, phase), 1.0)),
                            .init(color: Color.white.opacity(0.0), location: min(1.0, phase + 0.2))
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 1.3
                    }
                }
        }
    }
}
