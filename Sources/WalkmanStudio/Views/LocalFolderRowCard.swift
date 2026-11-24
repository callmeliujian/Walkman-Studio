import SwiftUI

struct LocalFolderRowCard: View {
    @ObservedObject private var localization = AppLocalization.shared
    let folder: LocalMusicFolder
    var onSelect: (() -> Void)? = nil
    var onRescan: (() -> Void)? = nil
    var onRelocate: (() -> Void)? = nil
    let onReveal: () -> Void
    let onRemove: () -> Void
    var onTransfer: (() -> Void)? = nil

    @State private var isHovered = false

    private var isMissing: Bool {
        folder.isMissing || !folder.existsOnDisk
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes <= 0 { return "0 GB" }
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576.0
        return String(format: "%.0f MB", mb)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { onSelect?() }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isMissing ? Color.orange.opacity(0.15) : Color.white.opacity(0.08))
                            .frame(width: 40, height: 40)
                        Image(systemName: isMissing ? "folder.badge.questionmark" : "folder.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(isMissing ? Color.orange : WalkmanTheme.silverLight)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(folder.displayName)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(.white)

                            if isMissing {
                                Text(L10n.tr("MISSING OR RENAMED"))
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.20))
                                    .foregroundStyle(Color.orange)
                                    .clipShape(Capsule())
                            } else {
                                Text(L10n.tr("\(folder.trackCount) tracks"))
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.10))
                                    .foregroundStyle(WalkmanTheme.silverLight)
                                    .clipShape(Capsule())
                            }

                            Text(formatBytes(folder.totalBytes))
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(WalkmanTheme.silverMuted)
                        }

                        Text(isMissing ? L10n.tr("\(folder.path) (Not found on disk)") : folder.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(isMissing ? Color.orange.opacity(0.85) : .secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                if isMissing, let onRelocate = onRelocate {
                    Button(action: onRelocate) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.gearshape")
                            Text(L10n.tr("Relocate..."))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.tr("Choose new directory for renamed or moved folder"))
                }

                if !isMissing, let onRescan = onRescan {
                    Button(action: onRescan) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WalkmanTheme.silverLight)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.tr("Rescan this folder"))
                }

                Button(action: onReveal) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WalkmanTheme.silverLight)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(L10n.tr("Reveal in Finder"))

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(L10n.tr("Remove folder from Local Music Library"))
            }
        }
        .padding(12)
        .background(WalkmanTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isMissing ? Color.orange.opacity(0.40) : Color.white.opacity(isHovered ? 0.16 : 0.06), lineWidth: isMissing ? 1.0 : 0.8)
        )
        .onHover { isHovered = $0 }
        .contextMenu {
            if isMissing, let onRelocate = onRelocate {
                Button(L10n.tr("Relocate Folder..."), action: onRelocate)
                Divider()
            }
            if let onTransfer = onTransfer {
                Button {
                    onTransfer()
                } label: {
                    Label(L10n.tr("Transfer Folder to Walkman"), systemImage: "arrow.right.circle.fill")
                }
                Divider()
            }
            Button(L10n.tr("Open Folder in Songs View")) {
                onSelect?()
            }
            Button(L10n.tr("Reveal in Finder"), action: onReveal)
            Divider()
            Button(L10n.tr("Remove from Local Library"), role: .destructive, action: onRemove)
        }
    }
}
