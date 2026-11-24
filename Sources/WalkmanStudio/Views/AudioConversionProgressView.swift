import SwiftUI

struct AudioConversionProgressView: View {
    let progress: AudioConversionProgress

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(L10n.tr("Current track conversion"))
                Spacer()
                if let fraction = progress.fraction {
                    Text("\(Int(fraction * 100))%")
                } else {
                    Text(L10n.tr("\(WalkmanEngine.formatDuration(progress.processedSeconds)) encoded"))
                }
            }
            .font(.caption.monospacedDigit())
            ImportProgressBar(progress: progress.fraction ?? 0, isIndeterminate: progress.fraction == nil)
        }
        .accessibilityElement(children: .combine)
    }
}
