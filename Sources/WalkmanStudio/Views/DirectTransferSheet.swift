import SwiftUI

struct DirectTransferSheet: View {
    @ObservedObject private var localization = AppLocalization.shared
    let targetName: String
    let current: Int
    let total: Int
    let currentTitle: String
    let progress: Double
    let conversionProgress: AudioConversionProgress?
    let isComplete: Bool
    let result: DirectTransferResult
    let onDone: () -> Void

    private var statusText: String {
        if isComplete {
            return L10n.tr("Imported \(result.transferred) · Skipped duplicates \(result.duplicates)")
        }
        if current == 0 { return L10n.tr("Checking destination...") }
        return L10n.tr("Track \(current) of \(total)")
    }

    var body: some View {
        VStack(spacing: 18) {
            // Header with Icon
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(WalkmanTheme.hiResGoldGradient)
                        .frame(width: 44, height: 44)
                        .shadow(color: WalkmanTheme.hiResGold.opacity(0.3), radius: 6, x: 0, y: 2)

                    Image(systemName: isComplete ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.black)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(isComplete ? L10n.tr("Transfer Complete") : L10n.tr("Transferring to Walkman..."))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text(targetName)
                        .font(.system(size: 12))
                        .foregroundStyle(WalkmanTheme.silverMuted)
                }

                Spacer()
            }

            // Progress Details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WalkmanTheme.silverLight)

                    Spacer()

                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(WalkmanTheme.hiResGold)
                }

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 7)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(WalkmanTheme.hiResGoldGradient)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))), height: 7)
                            .animation(.linear(duration: 0.15), value: progress)
                    }
                }
                .frame(height: 7)

                if isComplete && result.missing > 0 {
                    Text(L10n.tr("Missing source files: \(result.missing)"))
                        .font(.system(size: 11))
                        .foregroundStyle(WalkmanTheme.silverMuted)
                } else if !isComplete && !currentTitle.isEmpty {
                    Text(currentTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(WalkmanTheme.silverMuted)
                        .lineLimit(1)
                }
                if !isComplete, let conversionProgress {
                    AudioConversionProgressView(progress: conversionProgress)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
            )

            // Hardware compliance caption
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(WalkmanTheme.hiResGold)
                Text(L10n.tr("Baseline RGB 800x800 JPEG • Strict ID3v2.3 UTF-16 • AppleDouble Cleaned"))
                    .font(.system(size: 10))
                    .foregroundStyle(WalkmanTheme.silverDark)
            }

            if isComplete {
                Button(action: onDone) {
                    Text(L10n.tr("Done"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(WalkmanTheme.hiResGoldGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(WalkmanTheme.background)
    }
}
