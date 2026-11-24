import SwiftUI
import AppKit

struct PlayPauseCircleButton: View {
    @ObservedObject private var localization = AppLocalization.shared
    let isPlaying: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isEnabled ?
                                (isHovered ? [Color.white, Color(white: 0.94)] : [Color(white: 0.96), Color(white: 0.84)]) :
                                [Color.white.opacity(0.3), Color.white.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 36, height: 36)

                // Specular top highlight
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(isHovered ? 0.50 : 0.30), location: 0.0),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 6)
                    Spacer(minLength: 0)
                }
                .clipShape(Circle())

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(Color(red: 18 / 255, green: 18 / 255, blue: 22 / 255))
                    .offset(x: isPlaying ? 0 : 1)
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(isHovered ? 0.50 : 0.30), lineWidth: 0.85)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.35 : 0.20), radius: isHovered ? 4 : 2, x: 0, y: 1.5)
            .scaleEffect(isHovered && isEnabled ? 1.07 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.70), value: isHovered)
        }
        .buttonStyle(TactilePlayerButtonStyle())
        .disabled(!isEnabled)
        .keyboardShortcut(.space, modifiers: [])
        .help(isPlaying ? L10n.tr("Pause (Space)") : L10n.tr("Play (Space)"))
        .onHover { h in
            guard isEnabled else { return }
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
