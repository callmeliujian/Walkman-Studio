import Foundation
import AVFoundation
import AppKit
import Combine
import MediaPlayer

public final class AudioPlayerService: NSObject, ObservableObject, @unchecked Sendable {
    public static let shared: AudioPlayerService = {
        let service = AudioPlayerService(defaults: .standard)
        service.setupRemoteCommands()
        service.setupSystemMediaKeyMonitor()
        return service
    }()

    /// Dedicated high-frequency playback progress object.
    /// Observers of AudioPlayerService won't be invalidated by sub-second timer ticks.
    public let progress = PlaybackProgress()

    @Published public var currentTrack: Track?
    @Published public var isPlaying: Bool = false
    @Published public var volume: Float = 0.8 {
        didSet {
            player.volume = volume
        }
    }
    @Published public var currentCoverArt: NSImage?
    @Published public var isSeeking: Bool = false
    @Published private(set) var abRepeat = ABRepeatState.off
    @Published public var isShuffle: Bool {
        didSet {
            if oldValue != isShuffle {
                shuffledTrackIDs.removeAll()
                savePlaybackSession()
            }
        }
    }
    @Published var repeatMode: PlaybackRepeatMode {
        didSet {
            if oldValue != repeatMode { savePlaybackSession() }
        }
    }
    
    /// Timestamp where the current track started (e.g. SensMe highlight position)
    @Published public var currentHighlightStartTime: Double? = nil

    /// If set (e.g. 45.0 for SensMe Highlight Preview mode), automatically advances to the next track when duration is reached
    @Published public var highlightPreviewDuration: Double? = nil

    /// Optional callback to customize next track starting time in specialized modes like SensMe (isManualSkip indicates whether user skipped)
    public var onAdvanceToNextTrack: ((_ nextTrack: Track, _ isManualSkip: Bool) -> Double?)? = nil

    /// Convenience accessors forwarding to `progress`
    public var currentTime: Double {
        get { progress.currentTime }
        set { progress.currentTime = newValue }
    }
    public var duration: Double {
        get { progress.duration }
        set { progress.duration = newValue }
    }

    private var player: AVPlayer = AVPlayer()
    private let defaults: UserDefaults
    private var pendingSession: PlaybackSession?
    private var lastSavedPosition: Double = 0
    private var loadingRequest: UUID?
    private var seekRequest: UUID?
    private var timeObserverToken: Any?
    private var endObserverToken: NSObjectProtocol? {
        didSet {
            if let oldValue { NotificationCenter.default.removeObserver(oldValue) }
        }
    }
    private var shuffledTrackIDs: Set<Track.ID> = []
    private var localKeyMonitor: Any?
    public var currentQueue: [Track] = []

    /// Optional external tracks provider (e.g. from connected Walkman DAP or Local Library)
    public var fallbackTracksProvider: (@MainActor () -> [Track])?

    /// Optional dynamic queue provider for the currently selected/focused tab (e.g. Songs, Recently Added)
    public var activeQueueProvider: (@MainActor () -> [Track]?)?

    /// Effective queue guaranteed to return a usable list of tracks
    public var effectiveQueue: [Track] {
        if Thread.isMainThread {
            if let active = MainActor.assumeIsolated({ activeQueueProvider?() }), !active.isEmpty {
                return active
            }
        }
        if !currentQueue.isEmpty {
            return currentQueue
        }
        if Thread.isMainThread {
            if let list = MainActor.assumeIsolated({ fallbackTracksProvider?() }), !list.isEmpty {
                return list
            }
        }
        return LocalMusicLibraryService.shared.tracks
    }

    init(defaults: UserDefaults) {
        let session = PlaybackSession.load(from: defaults)
        self.defaults = defaults
        pendingSession = session
        isShuffle = session?.isShuffle ?? false
        repeatMode = session?.repeatMode ?? .off
        super.init()
        player.volume = volume
        setupTimeObserver()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate(_:)),
                                               name: NSApplication.willTerminateNotification, object: nil)
    }

    @objc private func applicationWillTerminate(_ notification: Notification) {
        savePlaybackSession()
    }

    func savePlaybackSession() {
        // Keep the last track, position and markers while its volume is disconnected.
        let position = currentTrack == nil ? pendingSession?.position ?? 0 : progress.currentTime
        let markers = currentTrack == nil ? pendingSession?.abRepeat ?? .off : abRepeat
        let session = PlaybackSession(track: currentTrack ?? pendingSession?.track, position: position,
                                      isShuffle: isShuffle, repeatMode: repeatMode, abRepeat: markers)
        session.save(to: defaults)
        lastSavedPosition = position
    }

    func restorePlaybackSessionIfAvailable() {
        guard currentTrack == nil, let session = pendingSession, let track = session.track else { return }
        let url = URL(fileURLWithPath: track.fullPath).resolvingSymlinksInPath()
        guard let file = try? url.resourceValues(forKeys: [.isRegularFileKey, .isReadableKey]),
              file.isRegularFile == true, file.isReadable == true else { return }
        load(track: track, in: [], autoPlay: false, startTime: session.resumePosition, abRepeat: session.abRepeat)
        // A saved playhead is independent of the SensMe highlight start.
        currentHighlightStartTime = nil
    }

    deinit {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        if let endObserverToken {
            NotificationCenter.default.removeObserver(endObserverToken)
        }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self, self.loadingRequest == nil, !self.isSeeking,
                  self.player.currentItem != nil else { return }
            let sec = self.player.currentTime().seconds
            guard sec.isFinite, sec >= 0 else { return }
            self.progress.currentTime = sec
            if self.isPlaying, abs(sec - self.lastSavedPosition) >= 5 {
                self.savePlaybackSession()
            }
            
            // Check if SensMe Highlight Preview duration has elapsed (e.g. 45 seconds from highlight start)
            if self.isPlaying, self.abRepeat.range == nil, let start = self.currentHighlightStartTime, let maxDur = self.highlightPreviewDuration, maxDur > 0 {
                if sec >= (start + maxDur) {
                    self.playNext(isManualSkip: false)
                }
            }
        }
    }

    private func observeEnd(of item: AVPlayerItem, for trackID: Track.ID) {
        let range = abRepeat.range
        item.forwardPlaybackEndTime = range.map { CMTime(seconds: $0.upperBound, preferredTimescale: 60000) } ?? .invalid
        endObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            guard let self, let item, self.player.currentItem === item,
                  self.currentTrack?.id == trackID, self.abRepeat.range == range, self.isPlaying else { return }
            if let range {
                // A late end notification can arrive after a seek has already moved inside the loop.
                // A seek just short of B can also reach the end before its completion runs.
                let playhead = item.currentTime()
                if self.seekRequest != nil, playhead < item.forwardPlaybackEndTime, playhead < item.duration { return }
                self.seek(to: range.lowerBound, savePosition: false)
                self.player.play()
                return
            }
            self.playNext(isManualSkip: false)
        }
    }

    // =========================================================================
    // SYSTEM DEVICE CONTROLS: MPRemoteCommandCenter & MPNowPlayingInfoCenter
    // =========================================================================

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Toggle Play / Pause (Media Key Play/Pause, Touch Bar, AirPods, Bluetooth headsets)
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.handleRemoteTogglePlayPause() ?? .commandFailed
        }

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.play()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.pause()
            return .success
        }

        // Next Track (Media Key Next F9, Touch Bar Next, Bluetooth Next)
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.playNext()
            return .success
        }

        // Previous Track (Media Key Prev F7, Touch Bar Prev, Bluetooth Prev)
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.playPrevious()
            return .success
        }

        // Scrubbing on Touch Bar / Now Playing Slider
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: posEvent.positionTime)
            return .success
        }
    }

    func handleRemoteTogglePlayPause() -> MPRemoteCommandHandlerStatus {
        togglePlayPause()
        return .success
    }

    // =========================================================================
    // HARDWARE KEYBOARD EVENT MONITOR: SPACEBAR & FUNCTION ROW MEDIA KEYS
    // =========================================================================

    private func setupSystemMediaKeyMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .systemDefined]) { [weak self] event in
            guard let self = self else { return event }

            // 1. SPACEBAR HANDLING (keyCode 49)
            // Works globally in Walkman Studio regardless of table or view focus.
            if event.type == .keyDown && event.keyCode == 49 {
                // If user is currently focused in an editable text field / search field, pass space through
                if let responder = NSApp.keyWindow?.firstResponder {
                    if responder is NSTextView || responder is NSTextField || responder is NSText {
                        return event
                    }
                }
                if !event.isARepeat {
                    self.togglePlayPause()
                }
                return nil // Consumed: prevents table selection jump or audio beep
            }

            // 2. FUNCTION ROW KEYS & KEYBOARD SHORTCUTS
            if event.type == .keyDown {
                // F7 (keyCode 98) -> Previous Track
                if event.keyCode == 98 {
                    self.playPrevious()
                    return nil
                }
                // F8 (keyCode 100) -> Play / Pause
                if event.keyCode == 100 {
                    if !event.isARepeat {
                        self.togglePlayPause()
                    }
                    return nil
                }
                // F9 (keyCode 101) -> Next Track
                if event.keyCode == 101 {
                    self.playNext()
                    return nil
                }

                // Cmd + Right Arrow (keyCode 124) -> Next Track
                if event.modifierFlags.contains(.command) && event.keyCode == 124 {
                    self.playNext()
                    return nil
                }
                // Cmd + Left Arrow (keyCode 123) -> Previous Track
                if event.modifierFlags.contains(.command) && event.keyCode == 123 {
                    self.playPrevious()
                    return nil
                }
            }

            // 3. SYSTEM-DEFINED HARDWARE MEDIA KEYS (NSSystemDefined Subtype 8)
            if event.type == .systemDefined && event.subtype.rawValue == 8 {
                let keyCode = Int32((event.data1 & 0xFFFF0000) >> 16)
                if keyCode == NX_KEYTYPE_PLAY {
                    // The same press is delivered through MPRemoteCommandCenter.
                    return nil
                }

                let keyFlags = (event.data1 & 0x0000FFFF)
                let isKeyDown = (((keyFlags & 0xFF00) >> 8)) == 0xA
                if isKeyDown {
                    switch keyCode {
                    case NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST:
                        self.playNext()
                        return nil
                    case NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND:
                        self.playPrevious()
                        return nil
                    default:
                        break
                    }
                }
            }

            return event
        }
    }

    public func updateNowPlayingInfo() {
        let center = MPNowPlayingInfoCenter.default()
        guard let track = currentTrack else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = track.title.isEmpty ? track.filename : track.title
        info[MPMediaItemPropertyArtist] = track.artist.isEmpty ? "Unknown Artist" : track.artist
        info[MPMediaItemPropertyAlbumTitle] = track.album.isEmpty ? "Unknown Album" : track.album
        let dur = progress.duration > 0 ? progress.duration : track.durationSeconds
        info[MPMediaItemPropertyPlaybackDuration] = max(1.0, dur)
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress.currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0

        if let art = currentCoverArt {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: art.size) { _ in art }
        }

        center.nowPlayingInfo = info
        // macOS uses this explicit state to route play and pause commands.
        center.playbackState = isPlaying ? .playing : .paused
    }

    public func prepare(track: Track, in queue: [Track] = [], autoPlay: Bool = false, startTime: Double? = nil) {
        if let current = currentTrack, current.id == track.id {
            if !queue.isEmpty {
                self.currentQueue = queue
            }
            if let start = startTime {
                self.currentHighlightStartTime = start
                seek(to: start)
            }
            if autoPlay && !isPlaying {
                play()
            }
            return
        }
        load(track: track, in: queue, autoPlay: autoPlay, startTime: startTime, abRepeat: .off)
    }

    private func load(track: Track, in queue: [Track], autoPlay: Bool, startTime: Double?, abRepeat: ABRepeatState) {
        pendingSession = nil
        self.abRepeat = abRepeat
        let request = UUID()
        loadingRequest = request
        seekRequest = nil
        isSeeking = false
        player.pause()
        self.currentTrack = track
        if !queue.isEmpty {
            self.currentQueue = queue
        } else if self.currentQueue.isEmpty {
            self.currentQueue = effectiveQueue
        }
        let initialTime = startTime ?? 0.0
        self.progress.currentTime = initialTime
        self.progress.duration = track.durationSeconds
        self.isPlaying = autoPlay
        self.currentHighlightStartTime = (initialTime > 0) ? initialTime : nil
        savePlaybackSession()

        let url = URL(fileURLWithPath: track.fullPath)
        
        // Asynchronous asset loading off the main UI thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
            let item = AVPlayerItem(asset: asset)
            
            DispatchQueue.main.async {
                guard let self, self.loadingRequest == request else { return }
                self.loadingRequest = nil
                self.player.replaceCurrentItem(with: item)
                self.observeEnd(of: item, for: track.id)
                // A scrub during asset loading supersedes the initial resume position.
                if self.progress.currentTime > 0 {
                    self.seek(to: self.progress.currentTime)
                }
                if self.isPlaying {
                    self.player.play()
                }
                self.updateNowPlayingInfo()
            }
        }

        loadArtwork(for: track)
        updateNowPlayingInfo()
    }

    public func play(track: Track, coverArt: NSImage? = nil, in queue: [Track] = [], startTime: Double? = nil) {
        prepare(track: track, in: queue, autoPlay: true, startTime: startTime)
        if let cover = coverArt {
            self.currentCoverArt = cover
        }
        updateNowPlayingInfo()
    }

    public func play() {
        if currentTrack != nil {
            if loadingRequest == nil {
                if let range = abRepeat.range, seekRequest == nil, player.currentTime().seconds >= range.upperBound {
                    seek(to: range.lowerBound)
                }
                player.play()
            }
            self.isPlaying = true
            updateNowPlayingInfo()
        } else if let first = effectiveQueue.first {
            play(track: first, in: effectiveQueue)
        }
    }

    public func playOrToggle(track: Track, coverArt: NSImage? = nil, in queue: [Track] = [], startTime: Double? = nil) {
        if currentTrack?.id == track.id {
            if let start = startTime {
                seek(to: start)
            }
            if let cover = coverArt {
                self.currentCoverArt = cover
            }
            togglePlayPause()
            return
        }
        play(track: track, coverArt: coverArt, in: queue, startTime: startTime)
    }

    public func pause() {
        player.pause()
        self.isPlaying = false
        savePlaybackSession()
        updateNowPlayingInfo()
    }

    public func stopAndClear() {
        pendingSession = nil
        abRepeat = .off
        loadingRequest = nil
        seekRequest = nil
        isSeeking = false
        player.pause()
        isPlaying = false
        endObserverToken = nil
        player.replaceCurrentItem(with: nil)
        shuffledTrackIDs.removeAll()
        currentTrack = nil
        currentQueue = []
        currentHighlightStartTime = nil
        highlightPreviewDuration = nil
        onAdvanceToNextTrack = nil
        progress.currentTime = 0.0
        progress.duration = 0.0
        currentCoverArt = nil
        savePlaybackSession()
        updateNowPlayingInfo()
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func advanceABRepeat() {
        guard let track = currentTrack, abRepeat.canAdvance(at: currentTime, duration: duration) else { return }
        switch abRepeat {
        case .off:
            abRepeat = .startMarked(currentTime)
            savePlaybackSession()
        case .startMarked(let start):
            abRepeat = .looping(start..<currentTime)
            if loadingRequest == nil, let item = player.currentItem {
                observeEnd(of: item, for: track.id)
            }
            seek(to: start)
            if isPlaying, loadingRequest == nil { player.play() }
        case .looping:
            clearABRepeat()
        }
    }

    func clearABRepeat() {
        guard abRepeat != .off else { return }
        let hadRange = abRepeat.range != nil
        abRepeat = .off
        savePlaybackSession()
        if hadRange, loadingRequest == nil, let item = player.currentItem, let track = currentTrack {
            observeEnd(of: item, for: track.id)
            if isPlaying { player.play() }
        }
    }

    public func seek(to seconds: Double) {
        seek(to: seconds, savePosition: true)
    }

    private func seek(to seconds: Double, savePosition: Bool) {
        guard currentTrack != nil, seconds.isFinite else { return }
        if let range = abRepeat.range, !range.contains(seconds) {
            clearABRepeat()
        }
        progress.currentTime = seconds
        if savePosition { savePlaybackSession() }
        guard loadingRequest == nil, let item = player.currentItem else { return }
        let request = UUID()
        seekRequest = request
        isSeeking = true
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 60000)
        let tolerance = abRepeat.range == nil ? CMTime(seconds: 0.05, preferredTimescale: 600) : .zero
        player.seek(to: targetTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self, weak item] finished in
            DispatchQueue.main.async {
                guard let self, self.seekRequest == request, self.player.currentItem === item else { return }
                self.seekRequest = nil
                self.isSeeking = false
                let actual = self.player.currentTime().seconds
                if finished, actual.isFinite, actual >= 0 {
                    self.progress.currentTime = actual
                }
                self.updateNowPlayingInfo()
            }
        }
        updateNowPlayingInfo()
    }

    /// Accurately jump to a specific timestamp in a track, seamlessly loading/playing it if necessary.
    public func seekTo(time seconds: Double, in track: Track? = nil) {
        let targetTrack = track ?? currentTrack
        guard let target = targetTrack else { return }

        if currentTrack?.id == target.id {
            seek(to: seconds)
            if !isPlaying { play() }
        } else {
            play(track: target, startTime: seconds)
        }
    }

    public func playNext(isManualSkip: Bool = true) {
        if isManualSkip { clearABRepeat() }
        if !isManualSkip, repeatMode == .one, currentTrack != nil {
            let start = highlightPreviewDuration == nil ? 0 : currentHighlightStartTime ?? 0
            restartCurrentTrack(at: start)
            return
        }

        let queue = effectiveQueue
        let canWrap = isManualSkip || repeatMode == .all
        guard let next = nextTrack(in: queue, canWrap: canWrap) else {
            if !isManualSkip, currentTrack != nil {
                pause()
                seek(to: 0)
            }
            return
        }

        let start = onAdvanceToNextTrack?(next, isManualSkip)
        if next.id == currentTrack?.id {
            currentQueue = queue
            restartCurrentTrack(at: start ?? 0)
        } else {
            play(track: next, in: queue, startTime: start)
        }
    }

    private func restartCurrentTrack(at start: Double) {
        currentHighlightStartTime = start > 0 ? start : nil
        seek(to: start)
        play()
    }

    private func nextTrack(in queue: [Track], canWrap: Bool) -> Track? {
        guard let current = currentTrack else { return queue.first }

        if isShuffle {
            shuffledTrackIDs.insert(current.id)
            if let next = queue.filter({ !shuffledTrackIDs.contains($0.id) }).randomElement() {
                return next
            }
            shuffledTrackIDs.removeAll()
            guard canWrap else { return nil }
            return queue.filter { $0.id != current.id }.randomElement() ?? queue.first
        }

        guard let index = queue.firstIndex(where: { $0.id == current.id }) else { return queue.first }
        let nextIndex = index + 1
        if nextIndex < queue.count { return queue[nextIndex] }
        return canWrap ? queue.first : nil
    }

    public func playPrevious(isManualSkip: Bool = true) {
        if isManualSkip { clearABRepeat() }
        let queue: [Track]
        if Thread.isMainThread, let active = MainActor.assumeIsolated({ activeQueueProvider?() }), !active.isEmpty {
            queue = active
            self.currentQueue = active
        } else {
            queue = effectiveQueue
        }
        guard !queue.isEmpty else { return }

        guard let current = currentTrack else {
            if let first = queue.first {
                let start = onAdvanceToNextTrack?(first, isManualSkip)
                play(track: first, in: queue, startTime: start)
            }
            return
        }

        // If played more than 3 seconds, standard media player rewind to start
        if progress.currentTime > 3.0 {
            seek(to: 0)
            return
        }

        if let idx = queue.firstIndex(where: { $0.id == current.id }) {
            let prevIdx = idx - 1
            if prevIdx >= 0 {
                let prev = queue[prevIdx]
                let start = onAdvanceToNextTrack?(prev, isManualSkip)
                play(track: prev, in: queue, startTime: start)
            } else if let last = queue.last {
                let start = onAdvanceToNextTrack?(last, isManualSkip)
                play(track: last, in: queue, startTime: start)
            } else {
                seek(to: 0)
            }
        } else {
            if let last = queue.last {
                let start = onAdvanceToNextTrack?(last, isManualSkip)
                play(track: last, in: queue, startTime: start)
            } else {
                seek(to: 0)
            }
        }
    }

    public func updateTrackInfo(track: Track, previousFullPath: String? = nil) {
        let originalID = previousFullPath ?? track.id
        for (idx, tr) in currentQueue.enumerated() where tr.id == originalID {
            currentQueue[idx] = track
        }
        if currentTrack?.id == originalID, originalID != track.id {
            prepare(track: track, in: currentQueue, autoPlay: isPlaying, startTime: progress.currentTime)
        }
        if currentTrack?.id == track.id {
            self.currentTrack = track
            loadArtwork(for: track)
            updateNowPlayingInfo()
        }
    }

    private func loadArtwork(for track: Track) {
        if let cached = CoverArtCache.shared.thumbnail(for: track) {
            self.currentCoverArt = cached
            self.updateNowPlayingInfo()
            return
        }
        CoverArtCache.shared.loadThumbnail(for: track, targetSize: 300) { [weak self] img in
            DispatchQueue.main.async {
                if self?.currentTrack?.id == track.id {
                    self?.currentCoverArt = img
                    self?.updateNowPlayingInfo()
                }
            }
        }
    }
}
