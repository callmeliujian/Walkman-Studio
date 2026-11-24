import SwiftUI

// MARK: - Hardware Optimization Toggle Chip View (32pt Liquid Glass Capsule)
struct HardwareOptimizationToggleChipView: View {
    @ObservedObject private var localization = AppLocalization.shared
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let help: String
    var disabled: Bool = false
    var onToggled: ((Bool) -> Void)? = nil

    @State private var isHovered = false

    private var isEffectivelyOn: Bool {
        !disabled && isOn
    }

    var body: some View {
        Button(action: {
            isOn.toggle()
            onToggled?(isOn)
        }) {
            HStack(spacing: 5.5) {
                Image(systemName: isEffectivelyOn ? "\(icon).fill" : icon)
                    .font(.system(size: 10.5, weight: isEffectivelyOn ? .semibold : .regular))
                    .foregroundStyle(
                        isEffectivelyOn ?
                            WalkmanTheme.silverLight :
                            (isHovered ? Color.white : WalkmanTheme.silverLight.opacity(0.85))
                    )

                Text(title)
                    .font(.system(size: 12, weight: isEffectivelyOn ? .semibold : .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(
                        isEffectivelyOn ?
                            Color.white :
                            (isHovered ? Color.white : WalkmanTheme.silverLight.opacity(0.85))
                    )

                if isEffectivelyOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(WalkmanTheme.silverLight)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .frame(height: 32)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                ZStack {
                    if isEffectivelyOn {
                        Color.white.opacity(isHovered ? 0.18 : 0.14)
                        VStack(spacing: 0) {
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(isHovered ? 0.38 : 0.28), location: 0.0),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 5.5)
                            Spacer(minLength: 0)
                        }
                    } else if isHovered {
                        Color.white.opacity(0.09)
                        VStack(spacing: 0) {
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.18), location: 0.0),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 5)
                            Spacer(minLength: 0)
                        }
                    } else {
                        Color.white.opacity(0.06)
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isEffectivelyOn ?
                            Color.white.opacity(isHovered ? 0.48 : 0.38) :
                            (isHovered ? Color.white.opacity(0.28) : Color.white.opacity(0.14)),
                        lineWidth: 0.85
                    )
            )
            .shadow(
                color: Color.black.opacity(isEffectivelyOn ? (isHovered ? 0.25 : 0.16) : (isHovered ? 0.12 : 0)),
                radius: isHovered ? 3 : 2,
                x: 0,
                y: 1
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .zIndex(isHovered ? 2 : 1)
        .disabled(disabled)
        .opacity(disabled ? 0.38 : 1.0)
        .help(help)
        .onHover { hovering in
            guard !disabled else { return }
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
