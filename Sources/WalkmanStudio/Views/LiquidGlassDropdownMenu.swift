import SwiftUI

// MARK: - Liquid Glass Dropdown Menu (38pt Standard Dropdown)
struct LiquidGlassDropdownMenu<Content: View>: View {
    @ObservedObject private var localization = AppLocalization.shared
    let title: String
    @ViewBuilder let menuContent: () -> Content

    @State private var isHovered = false

    var body: some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isHovered ? WalkmanTheme.silverLight : WalkmanTheme.silverMuted)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                ZStack {
                    Color.white.opacity(isHovered ? 0.12 : 0.07)
                    VStack(spacing: 0) {
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(isHovered ? 0.24 : 0.14), location: 0.0),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 7)
                        Spacer(minLength: 0)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(isHovered ? 0.32 : 0.14), lineWidth: 0.85)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.20 : 0.10), radius: 2, y: 1)
            .scaleEffect(isHovered ? 1.015 : 1.0)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
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
