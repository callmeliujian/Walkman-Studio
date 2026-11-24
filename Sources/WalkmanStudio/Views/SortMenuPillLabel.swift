import SwiftUI

// MARK: - Sort Menu Pill Label (32pt Liquid Glass Capsule)
struct SortMenuPillLabel: View {
    @ObservedObject private var localization = AppLocalization.shared
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4.5) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 10, weight: .semibold))
            Text(L10n.tr("Sort"))
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(height: 32)
        .foregroundStyle(isHovered ? Color.white : WalkmanTheme.silverLight)
        .background(
            ZStack {
                Color.white.opacity(isHovered ? 0.12 : 0.06)
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(isHovered ? 0.20 : 0.10), location: 0.0),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 5)
                    Spacer(minLength: 0)
                }
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(isHovered ? 0.22 : 0.10), lineWidth: 0.85)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.15 : 0), radius: 2, y: 1)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .contentShape(Capsule())
        .onHover { hovering in
            guard isHovered != hovering else { return }
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onDisappear {
            if isHovered {
                isHovered = false
                NSCursor.pop()
            }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovered)
    }
}
