import SwiftUI
import AppKit

struct LiquidGlassPlayerButton: View {
    @ObservedObject private var localization = AppLocalization.shared
    let systemName: String
    let size: CGFloat
    let isActive: Bool
    var isDisabled: Bool = false
    let helpText: String
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Liquid glass background capsule on hover
                Capsule()
                    .fill(Color.white.opacity(isHovered && !isDisabled ? 0.11 : 0.0))

                if isHovered && !isDisabled {
                    VStack(spacing: 0) {
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.22), location: 0.0),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 6)
                        Spacer(minLength: 0)
                    }
                    .clipShape(Capsule())

                    Capsule()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                }

                Image(systemName: systemName)
                    .font(.system(size: size, weight: isActive ? .bold : .medium))
                    .foregroundStyle(
                        isDisabled ? Color.white.opacity(0.20) :
                        (isActive ? WalkmanTheme.hiResGold : (isHovered ? .white : Color.white.opacity(0.70)))
                    )
            }
            .frame(width: 30, height: 30)
            .scaleEffect(isHovered && !isDisabled ? 1.08 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovered)
            .contentShape(Rectangle())
        }
        .buttonStyle(TactilePlayerButtonStyle())
        .disabled(isDisabled)
        .help(helpText)
        .onHover { h in
            guard !isDisabled else { return }
            isHovered = h
            if h { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
        .onDisappear {
            if isHovered {
                isHovered = false
                NSCursor.arrow.set()
            }
        }
    }
}
