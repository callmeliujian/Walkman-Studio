import SwiftUI
import AppKit

struct LiquidGlassTopBarButton: View {
    @ObservedObject private var localization = AppLocalization.shared
    let systemName: String
    var iconSize: CGFloat = 13
    var iconWeight: Font.Weight = .bold
    var buttonSize: CGFloat = 36
    let helpText: String
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Liquid glass background fill
                Circle()
                    .fill(Color.white.opacity(isHovered ? 0.14 : 0.08))

                // Specular top reflection sheen
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(isHovered ? 0.34 : 0.22), location: 0.0),
                            .init(color: .white.opacity(0.04), location: 0.6),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 7)
                    Spacer(minLength: 0)
                }
                .clipShape(Circle())

                // Hairline specular border
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(isHovered ? 0.32 : 0.20), location: 0.0),
                                .init(color: .white.opacity(isHovered ? 0.16 : 0.08), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.85
                    )

                Image(systemName: systemName)
                    .font(.system(size: iconSize, weight: iconWeight))
                    .foregroundStyle(isHovered ? .white : WalkmanTheme.silverLight)
            }
            .frame(width: buttonSize, height: buttonSize)
            .shadow(color: Color.black.opacity(isHovered ? 0.38 : 0.24), radius: isHovered ? 8 : 5, x: 0, y: isHovered ? 3 : 2)
            .scaleEffect(isHovered ? 1.06 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovered)
            .contentShape(Circle())
        }
        .buttonStyle(FullScreenTactileButtonStyle())
        .help(helpText)
        .onHover { h in
            isHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
