import SwiftUI
import AppKit

struct FullScreenTransportButton: View {
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
            Image(systemName: systemName)
                .font(.system(size: size, weight: isActive ? .bold : .semibold))
                .foregroundStyle(
                    isDisabled ? Color.white.opacity(0.20) :
                    (isActive ? WalkmanTheme.hiResGold : (isHovered ? .white : Color.white.opacity(0.70)))
                )
                .frame(width: 44, height: 44)
                .scaleEffect(isHovered && !isDisabled ? 1.12 : 1.0)
        }
        .buttonStyle(FullScreenTactileButtonStyle())
        .disabled(isDisabled)
        .help(helpText)
        .onHover { h in
            guard !isDisabled else { return }
            withAnimation(.spring(response: 0.20, dampingFraction: 0.72)) {
                isHovered = h
            }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
