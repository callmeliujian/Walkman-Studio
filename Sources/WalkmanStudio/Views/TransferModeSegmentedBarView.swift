import SwiftUI

// MARK: - Transfer Mode Segmented Bar View (Liquid Glass Matched Geometry)
struct TransferModeSegmentedBarView: View {
    @ObservedObject private var localization = AppLocalization.shared
    @Binding var targetMode: TransferTargetMode
    let onSelectMode: (TransferTargetMode) -> Void

    @Namespace private var modeNamespace
    @State private var activeModeId: String = TransferTargetMode.music.id

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TransferTargetMode.allCases) { mode in
                TransferModeTabPillView(
                    mode: mode,
                    isSelected: activeModeId == mode.id,
                    namespace: modeNamespace,
                    onSelect: {
                        guard targetMode != mode else { return }
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                            activeModeId = mode.id
                        }
                        onSelectMode(mode)
                    }
                )
            }
        }
        .padding(3)
        .frame(height: 38)
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
        )
        .fixedSize(horizontal: true, vertical: false)
        .onAppear {
            activeModeId = targetMode.id
        }
        .onChange(of: targetMode) { _, newMode in
            if activeModeId != newMode.id {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                    activeModeId = newMode.id
                }
            }
        }
    }
}
