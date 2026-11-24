import SwiftUI
import XCTest
@testable import WalkmanStudio

final class LibraryViewDeletionTests: XCTestCase {
    @MainActor
    func testDeletingFromContextMenuUpdatesRowsAndThenShowsEmptyStorage() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var tracks = try ["First", "Second"].map { title in
            let file = folder.appendingPathComponent(title + ".mp3")
            try Data().write(to: file)
            return Track(filename: file.lastPathComponent, relativePath: file.lastPathComponent, fullPath: file.path,
                         format: "MP3", title: title, artist: "Artist", album: "Album", trackNum: title,
                         year: "", genre: "", durationSeconds: 0, bitrateKbps: 0, sampleRate: 0,
                         bitsPerSample: 0, hasArtwork: false, sizeBytes: 0)
        }
        var requestedTrack: Track?
        func libraryView() -> LibraryView {
            LibraryView(tracks: tracks, isLoading: false, selectedTrackId: .constant(nil),
                        onInspectTrack: { _ in }, onGoToTransfer: {}, onDeleteTrack: { requestedTrack = $0 })
        }

        let player = AudioPlayerService.shared
        let previousProvider = player.activeQueueProvider
        let host = NSHostingView(rootView: libraryView())
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        defer {
            window.contentView = nil
            player.activeQueueProvider = previousProvider
        }

        for expected in tracks {
            try await waitForLayout(host) {
                self.table(in: host)?.numberOfRows == tracks.count
                    && player.activeQueueProvider?()?.map(\.id) == tracks.map(\.id)
            }
            let table = try XCTUnwrap(table(in: host))
            let row = table.rect(ofRow: 0)
            let point = table.convert(NSPoint(x: row.midX, y: row.midY), to: nil)
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: point, modifierFlags: [],
                                                         timestamp: 0, windowNumber: window.windowNumber,
                                                         context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
            let menu = try XCTUnwrap(table.menu(for: event))
            menu.update()
            let item = try XCTUnwrap(menu.items.firstIndex { $0.title == L10n.tr("Delete from Device") })
            menu.performActionForItem(at: item)
            try await waitForLayout(host) { requestedTrack?.id == expected.id }
            let target = try XCTUnwrap(requestedTrack)
            let removed = await WalkmanEngine.shared.deleteTrackFile(atPath: target.fullPath)
            XCTAssertTrue(removed)
            XCTAssertFalse(FileManager.default.fileExists(atPath: target.fullPath))
            tracks.removeAll { $0.id == target.id }
            host.rootView = libraryView()
            requestedTrack = nil
        }

        try await waitForLayout(host) {
            self.table(in: host) == nil && player.activeQueueProvider?()?.isEmpty == true
        }
    }

    @MainActor
    private func table(in view: NSView) -> NSTableView? {
        if let table = view as? NSTableView { return table }
        return view.subviews.lazy.compactMap { self.table(in: $0) }.first
    }

    @MainActor
    private func waitForLayout(_ host: NSView, until condition: () -> Bool,
                               file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            host.layoutSubtreeIfNeeded()
            if condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(condition(), "The library did not reach the expected state", file: file, line: line)
    }
}
