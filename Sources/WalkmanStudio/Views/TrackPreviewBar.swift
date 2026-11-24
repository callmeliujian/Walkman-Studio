import SwiftUI
import AppKit

public struct TrackPreviewBar: View {
    @ObservedObject private var localization = AppLocalization.shared
    @ObservedObject var player = AudioPlayerService.shared
    var libraryTracks: [Track] = []
    var isInspectorPresented: Bool = false
    let onOpenInspector: () -> Void
    var onOpenFullScreen: () -> Void = {}

    @State private var isArtworkHovered: Bool = false
    @State private var lastNonZeroVolume: Float = 0.8
    @State private var isVolumeExpanded: Bool = false
    @State private var isVolumeHovered: Bool = false
    @State private var isVolumeSpeakerHovered: Bool = false
    @State private var isEnlargeHovered: Bool = false

    public var body: some View {
        HStack(spacing: 12) {
            // LEFT: Transport controls (Shuffle, Prev, Play/Pause, Next, Repeat)
            transportControlsZone

            // CENTER: Now Playing Display Pod
            centerDisplayPod

            // RIGHT: Volume & Details Inspector Toggle
            trailingControlsZone
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(height: 56)
        .background(
            ZStack {
                // Native Apple macOS ultra-thin frosted glass material
                Rectangle()
                    .fill(.ultraThinMaterial)

                // Translucent obsidian veil (reveals UI elements underneath while keeping controls sharp)
                Color(red: 16 / 255, green: 17 / 255, blue: 21 / 255)
                    .opacity(0.24)

                // Subtle white ambient reflection
                Color.white
                    .opacity(0.04)

                // Top specular refraction sheen
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.28), location: 0.0),
                            .init(color: .white.opacity(0.06), location: 0.5),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 7)
                    Spacer(minLength: 0)
                }
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.24), location: 0.0),
                            .init(color: .white.opacity(0.10), location: 0.5),
                            .init(color: .white.opacity(0.06), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.85
                )
        )
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.45), radius: 22, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.20), radius: 4, x: 0, y: 1.5)
        .onExitCommand {
            if isVolumeExpanded {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    isVolumeExpanded = false
                }
            }
        }
    }

    // MARK: - Left: Transport Controls
    private var transportControlsZone: some View {
        HStack(spacing: 10) {
            // Shuffle
            LiquidGlassPlayerButton(
                systemName: "shuffle",
                size: 13,
                isActive: player.isShuffle,
                helpText: player.isShuffle ? L10n.tr("Shuffle: On") : L10n.tr("Shuffle: Off"),
                action: { player.isShuffle.toggle() }
            )

            // Previous
            LiquidGlassPlayerButton(
                systemName: "backward.fill",
                size: 14.5,
                isActive: false,
                isDisabled: player.currentTrack == nil && libraryTracks.isEmpty && player.effectiveQueue.isEmpty,
                helpText: L10n.tr("Previous track (F7 or Cmd+Left)"),
                action: { player.playPrevious() }
            )

            // Play / Pause prominent circular button
            PlayPauseCircleButton(
                isPlaying: player.isPlaying,
                isEnabled: player.currentTrack != nil || !libraryTracks.isEmpty || !player.effectiveQueue.isEmpty,
                action: {
                    if player.currentTrack != nil {
                        player.togglePlayPause()
                    } else if let first = player.effectiveQueue.first ?? libraryTracks.first {
                        player.play(track: first, in: player.effectiveQueue)
                    }
                }
            )

            // Next
            LiquidGlassPlayerButton(
                systemName: "forward.fill",
                size: 14.5,
                isActive: false,
                isDisabled: player.currentTrack == nil && libraryTracks.isEmpty && player.effectiveQueue.isEmpty,
                helpText: L10n.tr("Next track (F9 or Cmd+Right)"),
                action: { player.playNext() }
            )

            // Repeat
            LiquidGlassPlayerButton(
                systemName: player.repeatMode.symbolName,
                size: 13,
                isActive: player.repeatMode != .off,
                helpText: player.repeatMode.helpText,
                action: { player.repeatMode = player.repeatMode.next }
            )
            .accessibilityLabel(player.repeatMode.helpText)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Center: Display Pod
    private var centerDisplayPod: some View {
        ZStack {
            // Display pod inner glass styling (translucent)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.16), location: 0.0),
                            .init(color: .white.opacity(0.05), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )

            if let track = player.currentTrack {
                activeTrackDisplay(for: track)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
            } else {
                idleDisplay
                    .padding(.horizontal, 14)
            }
        }
        .frame(minWidth: 160, maxWidth: .infinity)
        .frame(height: 42)
        .contentShape(Rectangle())
        .onTapGesture {
            if isVolumeExpanded {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    isVolumeExpanded = false
                }
            }
        }
    }

    @ViewBuilder
    private func activeTrackDisplay(for track: Track) -> some View {
        let isHiRes = track.bitsPerSample > 16 || track.sampleRate > 48000

        HStack(spacing: 8) {
            // Artwork thumbnail (clickable to open inspector)
            Button(action: onOpenInspector) {
                ZStack {
                    if let img = player.currentCoverArt {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    } else {
                        TrackCoverThumbnail(track: track, size: 34, isPlaying: player.isPlaying)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(
                            isArtworkHovered ? Color.white.opacity(0.40) : (player.isPlaying ? Color.white.opacity(0.25) : Color.white.opacity(0.12)),
                            lineWidth: 0.8
                        )
                )
                .scaleEffect(isArtworkHovered ? 1.04 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isArtworkHovered)
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Click to view full metadata details & artwork"))
            .onHover { h in
                isArtworkHovered = h
                if h { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }
            .onDisappear {
                if isArtworkHovered {
                    isArtworkHovered = false
                    NSCursor.arrow.set()
                }
            }

            // Metadata & Scrubber
            VStack(alignment: .leading, spacing: 2) {
                // Top row: Title, Artist, Hi-Res Badge
                HStack(spacing: 5) {
                    Text(track.title.isEmpty ? "Unknown Title" : track.title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(player.isPlaying ? .white : Color(white: 0.9))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    if !track.artist.isEmpty {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary.opacity(0.6))
                            .fixedSize()

                        Text(track.artist)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(0.5)
                    }

                    if isHiRes {
                        Text("HR")
                            .font(.system(size: 7.5, weight: .black))
                            .foregroundStyle(WalkmanTheme.hiResGoldLight)
                            .padding(.horizontal, 3.5)
                            .padding(.vertical, 1)
                            .background(WalkmanTheme.hiResGold.opacity(0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(WalkmanTheme.hiResGold.opacity(0.40), lineWidth: 0.6))
                            .fixedSize()
                    }
                }

                // Bottom row: Isolated high-frequency timeline scrubber
                TrackScrubberRow(
                    isHiRes: isHiRes,
                    onSeek: { target in player.seek(to: target) },
                    onSeekingChanged: { editing in player.isSeeking = editing }
                )
            }
        }
    }

    private var idleDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WalkmanTheme.silverMuted.opacity(0.6))

            Text("Walkman Studio")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WalkmanTheme.silverMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Right: Responsive Apple-Style Volume & Enlarge Controls
    private var trailingControlsZone: some View {
        HStack(spacing: 6) {
            // Fluid responsive volume adjustment capsule
            volumeControlPod

            // Enlarge Button (Full Screen Now Playing with Artwork & Live Lyrics)
            enlargeButton
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var enlargeButton: some View {
        Button(action: onOpenFullScreen) {
            ZStack {
                // Liquid glass background capsule
                Capsule()
                    .fill(Color.white.opacity(isEnlargeHovered ? 0.12 : 0.05))

                // Specular top highlight sheen
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(isEnlargeHovered ? 0.28 : 0.10), location: 0.0),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 7)
                    Spacer(minLength: 0)
                }
                .clipShape(Capsule())

                // Hairline border
                Capsule()
                    .strokeBorder(
                        Color.white.opacity(isEnlargeHovered ? 0.24 : 0.10),
                        lineWidth: 0.85
                    )

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isEnlargeHovered ? .white : WalkmanTheme.silverLight)
            }
            .frame(width: 30, height: 30)
            .shadow(color: Color.black.opacity(isEnlargeHovered ? 0.28 : 0.0), radius: 4, x: 0, y: 1.5)
            .scaleEffect(isEnlargeHovered ? 1.07 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isEnlargeHovered)
            .contentShape(Rectangle())
        }
        .buttonStyle(TactilePlayerButtonStyle())
        .help(L10n.tr("Full Screen Player (Artwork & Live Lyrics)"))
        .onHover { h in
            isEnlargeHovered = h
            if h { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
        .onDisappear {
            if isEnlargeHovered {
                isEnlargeHovered = false
                NSCursor.arrow.set()
            }
        }
    }

    private var speakerIconName: String {
        if player.volume <= 0.001 {
            return "speaker.slash.fill"
        } else if player.volume < 0.5 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }

    private func toggleMute() {
        if player.volume > 0.001 {
            lastNonZeroVolume = player.volume
            player.volume = 0.0
        } else {
            player.volume = lastNonZeroVolume > 0.05 ? lastNonZeroVolume : 0.8
        }
    }

    @ViewBuilder
    private var volumeControlPod: some View {
        HStack(spacing: isVolumeExpanded ? 8 : 0) {
            if isVolumeExpanded {
                VolumeCapsuleSlider(volume: $player.volume)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.85, anchor: .trailing)),
                            removal: .opacity.combined(with: .scale(scale: 0.85, anchor: .trailing))
                        )
                    )
            }

            // Speaker Icon Button
            Button(action: {
                if NSEvent.modifierFlags.contains(.option) {
                    toggleMute()
                } else if !isVolumeExpanded {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        isVolumeExpanded = true
                    }
                } else {
                    if player.volume <= 0.001 {
                        toggleMute()
                    } else {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            isVolumeExpanded = false
                        }
                    }
                }
            }) {
                Image(systemName: speakerIconName)
                    .font(.system(size: 13, weight: isVolumeExpanded ? .semibold : .medium))
                    .foregroundStyle(
                        player.volume <= 0.001
                            ? Color.white.opacity(0.45)
                            : (isVolumeSpeakerHovered || isVolumeHovered ? .white : WalkmanTheme.silverLight)
                    )
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TactilePlayerButtonStyle())
            .help(
                isVolumeExpanded
                    ? (player.volume <= 0.001 ? L10n.tr("Unmute") : L10n.tr("Close Volume Slider (⌥+Click to Mute)"))
                    : L10n.tr("Adjust Volume (Click to expand, ⌥+Click to Mute)")
            )
            .onHover { h in
                isVolumeSpeakerHovered = h
                if h { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }
            .onDisappear {
                if isVolumeSpeakerHovered {
                    isVolumeSpeakerHovered = false
                    NSCursor.arrow.set()
                }
            }
        }
        .padding(.leading, isVolumeExpanded ? 10 : 3)
        .padding(.trailing, isVolumeExpanded ? 8 : 3)
        .padding(.vertical, 3)
        .frame(height: 30)
        .background(
            ZStack {
                if isVolumeExpanded {
                    Capsule()
                        .fill(Color.white.opacity(0.12))

                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.20), location: 0.0),
                            .init(color: .white.opacity(0.04), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(Capsule())
                } else {
                    Capsule()
                        .fill(Color.white.opacity(isVolumeHovered ? 0.09 : 0.05))

                    VStack(spacing: 0) {
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(isVolumeHovered ? 0.22 : 0.08), location: 0.0),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 7)
                        Spacer(minLength: 0)
                    }
                    .clipShape(Capsule())
                }
            }
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    Color.white.opacity(isVolumeExpanded ? 0.24 : (isVolumeHovered ? 0.20 : 0.10)),
                    lineWidth: 0.85
                )
        )
        .clipShape(Capsule())
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.16)) {
                isVolumeHovered = h
            }
        }
    }
}
