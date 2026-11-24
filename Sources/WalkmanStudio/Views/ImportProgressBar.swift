import SwiftUI

// MARK: - Import Progress Bar (Liquid Glass)
struct ImportProgressBar: View {
    @ObservedObject private var localization = AppLocalization.shared
    let progress: Double
    let isIndeterminate: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Capsule Track
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.85))

                // Fill Bar
                if !isIndeterminate {
                    let fillWidth = max(8, geo.size.width * CGFloat(min(max(progress, 0.0), 1.0)))
                    Capsule()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: WalkmanTheme.silverLight, location: 0.0),
                                    .init(color: WalkmanTheme.silver, location: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth)
                        .overlay(
                            VStack(spacing: 0) {
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.60), location: 0.0),
                                        .init(color: Color.clear, location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 3)
                                Spacer(minLength: 0)
                            }
                            .clipShape(Capsule())
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                } else {
                    IndeterminateLiquidGlassBar()
                }
            }
        }
        .frame(height: 8)
        .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.82), value: progress)
    }
}
