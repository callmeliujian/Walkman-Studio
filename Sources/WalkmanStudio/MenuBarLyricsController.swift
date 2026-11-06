import AppKit
import Combine

/// Uses the same parsed timeline and lead time as the now-playing lyrics view.
enum MenuBarLyricText {
    // A stable, compact footprint leaves more room for the foreground app's menus.
    static let itemWidth: CGFloat = 180
    static let font = NSFont.systemFont(ofSize: 13)

    struct Segment: Equatable {
        let text: String
        let start: Double
        let end: Double
    }

    static func currentSegment(
        in lines: [MetadataStudioView.ParsedLyricLine], at time: Double, duration: Double
    ) -> Segment? {
        guard time.isFinite,
              let index = lines.lastIndex(where: { ($0.timeInSeconds ?? .infinity) <= time + 0.5 }),
              let timestamp = lines[index].timeInSeconds else { return nil }
        let start = max(0, timestamp - 0.5)
        let next = lines.dropFirst(index + 1).compactMap(\.timeInSeconds).first { $0 > timestamp }
        let end = next.map { max(start, $0 - 0.5) }
            ?? (duration.isFinite && duration > start ? duration : start + 8)
        return Segment(text: lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines), start: start, end: end)
    }

    static func currentLine(in lines: [MetadataStudioView.ParsedLyricLine], at time: Double) -> String? {
        let text = currentSegment(in: lines, at: time, duration: 0)?.text
        return text?.isEmpty == false ? text : nil
    }

    /// Draw the whole shaped string through a viewport, holding briefly at both ends.
    /// Playback time is the only clock, so pauses and seeks need no animation state.
    static func scrollOffset(
        textWidth: CGFloat, viewportWidth: CGFloat, at time: Double, start: Double, end: Double
    ) -> CGFloat {
        guard textWidth.isFinite, viewportWidth.isFinite, time.isFinite,
              start.isFinite, end.isFinite, end > start else { return 0 }
        let overflow = max(0, textWidth - max(0, viewportWidth))
        guard overflow > 0 else { return 0 }
        let hold = min(0.7, (end - start) * 0.15)
        let progress = min(1, max(0, (time - start - hold) / (end - start - 2 * hold)))
        return overflow * progress
    }

    /// A long fallback title repeats at a readable speed during lyric-free passages.
    static func fallbackScrollOffset(textWidth: CGFloat, viewportWidth: CGFloat, at time: Double, start: Double) -> CGFloat {
        guard time.isFinite, start.isFinite, textWidth.isFinite, viewportWidth.isFinite else { return 0 }
        let cycle = max(8, Double(max(0, textWidth - viewportWidth)) / 25 + 1.4)
        let elapsed = max(0, time - start).truncatingRemainder(dividingBy: cycle)
        return scrollOffset(textWidth: textWidth, viewportWidth: viewportWidth, at: elapsed, start: 0, end: cycle)
    }
}

/// The native status button still owns highlighting, clicks, and its menu.
/// This child only paints, and never intercepts a mouse event.
@MainActor
private final class MenuBarLyricView: NSView {
    private var text = ""
    private var playing = false
    private var menuIsOpen = false
    private(set) var textWidth: CGFloat = 0
    private var offset: CGFloat = 0
    var viewportWidth: CGFloat { max(0, bounds.width - 38) }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(text: String, playing: Bool) {
        let singleLine = text.components(separatedBy: .newlines).joined(separator: " ")
        guard self.text != singleLine || self.playing != playing else { return }
        self.text = singleLine
        self.playing = playing
        textWidth = (singleLine as NSString).size(withAttributes: [.font: MenuBarLyricText.font]).width
        needsDisplay = true
    }

    func update(offset: CGFloat) {
        guard self.offset != offset else { return }
        self.offset = offset
        needsDisplay = true
    }

    func setMenuOpen(_ isOpen: Bool) {
        menuIsOpen = isOpen
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // NSMenuDelegate supplies the state directly: willOpen/didClose can run
        // before the native button finishes changing its highlight.
        let color = menuIsOpen ? NSColor.selectedMenuItemTextColor : NSColor.labelColor
        let symbol = NSImage(systemSymbolName: playing ? "music.note" : "pause.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))?
            .withSymbolConfiguration(.init(paletteColors: [color]))
        symbol?.draw(in: NSRect(x: 8, y: (bounds.height - 14) / 2, width: 14, height: 14))

        let attributes: [NSAttributedString.Key: Any] = [.font: MenuBarLyricText.font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: 30, y: 0, width: viewportWidth, height: bounds.height)).addClip()
        (text as NSString).draw(at: NSPoint(x: 30 - offset, y: (bounds.height - size.height) / 2), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
    }
}

/// App-scoped so lyrics keep updating when the main window is minimized or closed.
@MainActor
final class MenuBarLyricsController: NSObject, ObservableObject, NSMenuDelegate {
    static let shared = MenuBarLyricsController()
    private static let preferenceKey = "WalkmanStudio.showMenuBarLyrics"

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.preferenceKey)
            loadLyrics(for: player.currentTrack)
        }
    }

    private let player = AudioPlayerService.shared
    private var statusItem: NSStatusItem?
    private var subscriptions = Set<AnyCancellable>()
    private var lines: [MetadataStudioView.ParsedLyricLine] = []
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = UUID()
    private var lyricView: MenuBarLyricView?

    private override init() {
        isEnabled = UserDefaults.standard.object(forKey: Self.preferenceKey) as? Bool ?? true
        super.init()
    }

    func start() {
        guard subscriptions.isEmpty else { return }
        // Receive after @Published's willSet, so rendering sees the committed player state.
        player.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in self?.loadLyrics(for: track) }
            .store(in: &subscriptions)
        player.progress.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &subscriptions)
        player.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .trackMetadataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.loadLyrics(for: self.player.currentTrack)
            }
            .store(in: &subscriptions)
    }

    private func loadLyrics(for track: Track?) {
        loadTask?.cancel()
        let generation = UUID()
        loadGeneration = generation
        lines = []
        refresh()
        guard isEnabled, let track else { return }

        loadTask = Task { [weak self] in
            // Tag extraction can read a device or large audio file; keep it off the UI thread.
            let parsed = await Task.detached(priority: .utility) {
                let raw = AudioTagger.shared.extractLyrics(fileURL: URL(fileURLWithPath: track.fullPath))
                return MetadataStudioView.parseLyrics(raw, durationSeconds: track.durationSeconds)
            }.value
            guard !Task.isCancelled, let self,
                  self.loadGeneration == generation,
                  self.player.currentTrack?.id == track.id else { return }
            self.lines = parsed
            self.refresh()
        }
    }

    private func refresh() {
        guard isEnabled, let track = player.currentTrack else {
            // Keep the same item so toggling lyrics or stopping playback preserves its position.
            statusItem?.isVisible = false
            return
        }

        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: MenuBarLyricText.itemWidth)
            item.autosaveName = "WalkmanStudio.MenuBarLyrics"
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            if let button = item.button {
                let view = MenuBarLyricView(frame: button.bounds)
                view.autoresizingMask = [.width, .height]
                button.addSubview(view)
                lyricView = view
            }
            statusItem = item
        }
        statusItem?.isVisible = true

        let duration = player.duration > 0 ? player.duration : track.durationSeconds
        let segment = MenuBarLyricText.currentSegment(in: lines, at: player.currentTime, duration: duration)
        let hasLyric = segment?.text.isEmpty == false
        let text = hasLyric ? segment!.text
            : [track.title, track.artist].filter { !$0.isEmpty }.joined(separator: " — ")
        guard let button = statusItem?.button, let lyricView else { return }
        lyricView.update(text: text, playing: player.isPlaying)
        let offset: CGFloat
        if hasLyric, let segment {
            offset = MenuBarLyricText.scrollOffset(
                textWidth: lyricView.textWidth, viewportWidth: lyricView.viewportWidth,
                at: player.currentTime, start: segment.start, end: segment.end
            )
        } else {
            offset = MenuBarLyricText.fallbackScrollOffset(
                textWidth: lyricView.textWidth, viewportWidth: lyricView.viewportWidth,
                at: player.currentTime, start: segment?.start ?? 0
            )
        }
        lyricView.update(offset: offset)
        button.setAccessibilityLabel(text)
        button.toolTip = "\(track.title) — \(track.artist)\n\(text)"
    }

    func menuWillOpen(_ menu: NSMenu) {
        lyricView?.setMenuOpen(true)
        menu.removeAllItems()
        let title = NSMenuItem(title: player.currentTrack?.title ?? "Walkman Studio", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        addItem(to: menu, title: player.isPlaying ? L10n.tr("Pause") : L10n.tr("Play"), action: #selector(togglePlayback))
        addItem(to: menu, title: L10n.tr("Previous Track"), action: #selector(previousTrack))
        addItem(to: menu, title: L10n.tr("Next Track"), action: #selector(nextTrack))
        menu.addItem(.separator())
        addItem(to: menu, title: L10n.tr("Show Lyrics in Menu Bar"), action: #selector(toggleEnabled)).state = .on
    }

    func menuDidClose(_ menu: NSMenu) {
        lyricView?.setMenuOpen(false)
    }

    @discardableResult
    private func addItem(to menu: NSMenu, title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func togglePlayback() { player.togglePlayPause() }
    @objc private func previousTrack() { player.playPrevious() }
    @objc private func nextTrack() { player.playNext() }
    @objc private func toggleEnabled() { isEnabled.toggle() }
}
