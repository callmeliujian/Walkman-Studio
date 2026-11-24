import SwiftUI

// -----------------------------------------------------------------------------
// ENHANCED QUEUE ITEM ROW (PREMIUM GLASS CARD DESIGN)
// -----------------------------------------------------------------------------
struct QueueItemRow: View {
    @ObservedObject private var localization = AppLocalization.shared
    @Binding var item: TransferItem
    let isThisPlaying: Bool
    let destinationExtension: String
    var rootFolderName: String = "MUSIC"
    var isLearningMode: Bool = false
    var destinationDriveName: String = "Walkman"
    let onTogglePlay: () -> Void
    let onPickArtwork: () -> Void
    let onOptimize: () -> Void
    let onFetchLyrics: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // Play / Pause preview button
                Button(action: onTogglePlay) {
                    ZStack {
                        Circle()
                            .fill(isThisPlaying ? AnyShapeStyle(WalkmanTheme.silverGradient) : AnyShapeStyle(Color.white.opacity(isHovered ? 0.16 : 0.09)))
                            .frame(width: 32, height: 32)

                        Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isThisPlaying ? Color(red: 20/255, green: 20/255, blue: 24/255) : Color.white)
                            .offset(x: isThisPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
                .help(isThisPlaying ? L10n.tr("Pause audio preview") : L10n.tr("Play audio preview"))

                // Cover Artwork Thumbnail with Hardware Compliance Badge
                ZStack(alignment: .bottomTrailing) {
                    if let artData = item.artworkData, let img = NSImage(data: artData) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 46, height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 46, height: 46)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.tertiary)
                            )
                    }

                    // Compliance indicator dot
                    if item.artworkData != nil {
                        Circle()
                            .fill(item.isArtworkOptimized ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                            .offset(x: 2, y: 2)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isThisPlaying ? WalkmanTheme.silver : Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                .onTapGesture {
                    onPickArtwork()
                }
                .help(L10n.tr("Click to select custom album art or inspect compliance"))

                // Track Details & Metadata Hierarchy
                VStack(alignment: .leading, spacing: 3) {
                    // Line 1: Track Number Badge + Title & Badges
                    HStack(spacing: 6) {
                        let tNum = item.trackNumber.components(separatedBy: "/").first?.trimmingCharacters(in: .whitespaces) ?? ""
                        if !tNum.isEmpty, let numInt = Int(tNum), numInt > 0 {
                            Text(String(format: "%02d", numInt))
                                .font(WalkmanFont.monoSmall)
                                .foregroundStyle(WalkmanTheme.hiResGoldLight)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(WalkmanTheme.hiResGold.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                        .stroke(WalkmanTheme.hiResGold.opacity(0.35), lineWidth: 0.75)
                                )
                                .help(L10n.tr("Track \(numInt)"))
                        }

                        Text(item.title.isEmpty ? item.sourceURL.deletingPathExtension().lastPathComponent : item.title)
                            .font(WalkmanFont.bodyBold)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if item.bitsPerSample > 16 || item.sampleRate > 48000 {
                            Text(L10n.tr("Hi-Res"))
                                .font(WalkmanFont.badge)
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 1.5)
                                .background(WalkmanTheme.hiResGoldGradient)
                                .foregroundStyle(Color(red: 20/255, green: 20/255, blue: 24/255))
                                .clipShape(RoundedRectangle(cornerRadius: 2.5))
                        }

                        if item.isDuplicateOnWalkman {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                Text(L10n.tr("On \(destinationDriveName)"))
                                    .font(WalkmanFont.badge)
                            }
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1.5)
                            .background(Color.orange.opacity(0.18))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 2.5))
                            .overlay(RoundedRectangle(cornerRadius: 2.5).stroke(Color.orange.opacity(0.4), lineWidth: 0.6))
                            .help(item.duplicateMatchInfo ?? L10n.tr("Already present on \(destinationDriveName)"))
                        }
                    }

                    // Line 2: Artist • Album (Year)
                    HStack(spacing: 5) {
                        let artistText = item.artist.isEmpty ? "Unknown Artist" : item.artist
                        let albumText = item.album.isEmpty ? "Unknown Album" : item.album
                        Text("\(artistText) • \(albumText)")
                            .font(WalkmanFont.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if !item.year.isEmpty {
                            Text("(\(item.year))")
                                .font(WalkmanFont.monoSmall)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // Duplicate Match Detail Callout
                    if item.isDuplicateOnWalkman, let matchInfo = item.duplicateMatchInfo {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8.5))
                                .foregroundStyle(.orange)
                            Text(L10n.tr("Duplicate: \(matchInfo)"))
                                .font(WalkmanFont.monoSmall)
                                .foregroundStyle(.orange.opacity(0.95))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .stroke(Color.orange.opacity(0.28), lineWidth: 0.65)
                        )
                    }

                    // Line 3: Tech Specs & Route Preview
                    HStack(spacing: 6) {
                        let quality = item.sampleRate > 0 ? "\(item.bitsPerSample)b/\(item.sampleRate/1000)k" : item.format
                        Text(quality)
                            .font(WalkmanFont.badge)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(.white.opacity(0.85))

                        if item.bitrateKbps > 0 {
                            Text("\(item.bitrateKbps)k")
                                .font(WalkmanFont.monoSmall)
                                .foregroundStyle(.tertiary)
                        }

                        if item.durationSeconds > 0 {
                            Text(WalkmanEngine.formatDuration(item.durationSeconds))
                                .font(WalkmanFont.monoSmall)
                                .foregroundStyle(.tertiary)
                        }

                        if let lyr = item.lyrics, !lyr.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "quote.bubble.fill")
                                    .font(.system(size: 8))
                                Text(item.isLyricsSynced ? L10n.tr("Synced .LRC") : L10n.tr("Plain Lyrics"))
                                    .font(WalkmanFont.badge)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                        }

                        // Subtle clean destination breadcrumb
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                            let cleanArtist = WalkmanEngine.shared.sanitizeFilename(item.artist.isEmpty ? "Unknown Artist" : item.artist)
                            let cleanAlbum = WalkmanEngine.shared.sanitizeFilename(item.album.isEmpty ? "Unknown Album" : item.album)
                            let cleanTitle = WalkmanEngine.shared.sanitizeFilename(item.title.isEmpty ? item.sourceURL.deletingPathExtension().lastPathComponent : item.title)
                            let tInt = Int(item.trackNumber.components(separatedBy: "/").first ?? "1") ?? 1
                            let trackPrefix = String(format: "%02d", tInt)
                            Text("/\(rootFolderName)/\(cleanArtist)/\(cleanAlbum)/\(trackPrefix) - \(cleanTitle).\(destinationExtension)")
                                .font(WalkmanFont.monoSmall)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .foregroundStyle(.secondary.opacity(0.65))
                    }
                }

                Spacer()

                // Status Badge
                switch item.status {
                case .pending:
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 5, height: 5)
                        Text(L10n.tr("Ready"))
                            .font(WalkmanFont.badge)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())

                case .optimizing:
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.55).frame(width: 12, height: 12)
                        Text(L10n.tr("Optimizing..."))
                            .font(WalkmanFont.badge)
                            .foregroundStyle(WalkmanTheme.silverLight)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())

                case .converting:
                    HStack(spacing: 5) {
                        ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                        Text(L10n.tr("Transferring..."))
                            .font(WalkmanFont.badge)
                            .foregroundStyle(WalkmanTheme.silverLight)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(WalkmanTheme.hiResGold.opacity(0.15))
                    .foregroundStyle(WalkmanTheme.hiResGold)
                    .clipShape(Capsule())

                case .success:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                        Text(L10n.tr("Transferred"))
                            .font(WalkmanFont.badge)
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())

                case .skipped(let reason):
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.right.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text(reason)
                            .font(WalkmanFont.badge)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                    .help(reason)

                case .failed(let err):
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                        Text(err)
                            .font(WalkmanFont.subheadline)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.12))
                    .clipShape(Capsule())
                }

                // Row Action Buttons
                HStack(spacing: 4) {
                    if !isLearningMode && item.isMissingMetadata {
                        Button(action: onOptimize) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                                .padding(6)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(L10n.tr("Auto-fetch missing metadata from internet"))
                    }

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isHovered ? .white : .secondary)
                            .padding(6)
                            .background(Color.white.opacity(isHovered ? 0.12 : 0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(L10n.tr("Edit tags, artwork, lyrics, and destination in popup window"))

                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(Color.white.opacity(isHovered ? 0.08 : 0.04))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(L10n.tr("Remove from queue"))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isThisPlaying ? Color.white.opacity(0.08) : (isHovered ? WalkmanTheme.cardHover : WalkmanTheme.card.opacity(0.55)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isThisPlaying ? WalkmanTheme.silver.opacity(0.4) : (isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.04)), lineWidth: 1)
        )
        .onHover { h in isHovered = h }
        .onTapGesture(count: 2) {
            onEdit()
        }
        .contextMenu {
            Button(action: onTogglePlay) {
                Label(isThisPlaying ? L10n.tr("Pause Preview") : L10n.tr("Play Preview"), systemImage: isThisPlaying ? "pause.fill" : "play.fill")
            }
            Divider()
            if !isLearningMode {
                Button(action: onOptimize) {
                    Label(L10n.tr("Fetch Online Tags & Cover Art"), systemImage: "sparkles")
                }
                Button(action: onFetchLyrics) {
                    Label(L10n.tr("Fetch Synchronized Lyrics (.LRC)"), systemImage: "quote.bubble")
                }
            }
            Button(action: onPickArtwork) {
                Label(L10n.tr("Choose Custom Album Art..."), systemImage: "photo")
            }
            Button(action: onEdit) {
                Label(L10n.tr("Edit Metadata & Artwork..."), systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: onRemove) {
                Label(L10n.tr("Remove from Queue"), systemImage: "trash")
            }
        }
    }
}
