import SwiftUI

// MARK: - Transfer Batch Action Button (32pt Liquid Glass Capsule)
struct TransferBatchActionButton: View {
    @ObservedObject private var localization = AppLocalization.shared
    let title: String
    let icon: String
    var isLoading: Bool = false
    var isDestructive: Bool = false
    var isDisabled: Bool = false
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4.5) {
                if isLoading {
                    ProgressView().scaleEffect(0.55).frame(width: 12, height: 12)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(height: 32)
            .foregroundStyle(
                isDestructive ?
                    (isHovered ? Color(red: 255/255, green: 130/255, blue: 120/255) : Color(red: 255/255, green: 105/255, blue: 95/255)) :
                    (isHovered ? Color.white : WalkmanTheme.silverLight)
            )
            .background(
                ZStack {
                    if isDestructive {
                        Color.red.opacity(isHovered ? 0.18 : 0.10)
                    } else {
                        Color.white.opacity(isHovered ? 0.12 : 0.06)
                    }

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
                    .stroke(
                        isDestructive ?
                            Color.red.opacity(isHovered ? 0.40 : 0.22) :
                            Color.white.opacity(isHovered ? 0.22 : 0.10),
                        lineWidth: 0.85
                    )
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.15 : 0), radius: 2, y: 1)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .zIndex(isHovered ? 2 : 1)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
        .help(help)
        .onHover { hovering in
            guard !isDisabled else { return }
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
