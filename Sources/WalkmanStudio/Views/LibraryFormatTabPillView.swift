import SwiftUI

struct LibraryFormatTabPillView: View {
    @ObservedObject private var localization = AppLocalization.shared
    let option: LibraryFormatOption
    let isSelected: Bool
    let namespace: Namespace.ID
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 5.5) {
                if let icon = option.icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                }
                Text(L10n.lookup(option.title))
                    .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(height: 32)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(
                isSelected ?
                    (option.isHiRes ? WalkmanTheme.hiResGoldLight : Color.white) :
                    (isHovered ? Color.white : Color.white.opacity(0.70))
            )
            .background(
                ZStack {
                    if isSelected {
                        // Liquid Glass Active Pill Highlight — smoothly transfers via matched geometry
                        LiquidGlassActivePill(isHiRes: option.isHiRes, isHovered: isHovered)
                            .matchedGeometryEffect(id: "activeTabHighlight", in: namespace)
                    } else if isHovered {
                        // Liquid Glass Hover Pill (Round frosted glass box)
                        LiquidGlassHoverPill()
                    } else {
                        // Transparent hit-testable canvas
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
