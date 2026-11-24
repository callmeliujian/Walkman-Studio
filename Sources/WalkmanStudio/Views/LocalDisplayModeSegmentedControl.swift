import SwiftUI

struct LocalDisplayModeSegmentedControl: View {
    @ObservedObject private var localization = AppLocalization.shared
    @Binding var displayMode: LocalDisplayMode
    @Namespace private var highlightNamespace
    @State private var activeHighlightId: LocalDisplayMode = .songs

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LocalDisplayMode.allCases) { mode in
                LocalDisplayModePillView(
                    mode: mode,
                    isSelected: activeHighlightId == mode,
                    namespace: highlightNamespace,
                    onSelect: {
                        guard displayMode != mode else { return }
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                            activeHighlightId = mode
                        }
                        displayMode = mode
                    }
                )
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.8))
        .fixedSize(horizontal: true, vertical: false)
        .onAppear {
            activeHighlightId = displayMode
        }
        .onChange(of: displayMode) { _, newMode in
            if activeHighlightId != newMode {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                    activeHighlightId = newMode
                }
            }
        }
    }
}
