import SwiftUI

struct TransferModeTabPillView: View {
    @ObservedObject private var localization = AppLocalization.shared
    let mode: TransferTargetMode
    let isSelected: Bool
    let namespace: Namespace.ID
    let onSelect: () -> Void

    @State private var isHovered = false

    private var labelTitle: String {
        switch mode {
        case .music:
            return L10n.tr("Music Library")
        case .learning:
            return L10n.tr("Language Study")
        }
    }

    private var isGold: Bool {
        mode == .learning
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                Text(labelTitle)
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
                    (isGold ? WalkmanTheme.hiResGoldLight : Color.white) :
                    (isHovered ? (isGold ? WalkmanTheme.hiResGoldLight : Color.white) : Color.white.opacity(0.70))
            )
            .background(
                ZStack {
                    if isSelected {
                        ActiveModePillBackground(isGold: isGold, isHovered: isHovered)
                            .matchedGeometryEffect(id: "activeTransferModeHighlight", in: namespace)
                    } else if isHovered {
                        HoverModePillBackground()
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
