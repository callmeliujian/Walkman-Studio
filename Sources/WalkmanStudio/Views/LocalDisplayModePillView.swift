import SwiftUI

struct LocalDisplayModePillView: View {
    @ObservedObject private var localization = AppLocalization.shared
    let mode: LocalDisplayMode
    let isSelected: Bool
    let namespace: Namespace.ID
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                Text(L10n.lookup(mode.rawValue))
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 32)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(isSelected ? Color.white : (isHovered ? Color.white : Color.white.opacity(0.70)))
            .background(
                ZStack {
                    if isSelected {
                        LiquidGlassActivePill(isHiRes: false, isHovered: isHovered)
                            .matchedGeometryEffect(id: "activeDisplayModeHighlight", in: namespace)
                    } else if isHovered {
                        LiquidGlassHoverPill()
                    } else {
                        Color.white.opacity(0.001)
                    }
                }
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
