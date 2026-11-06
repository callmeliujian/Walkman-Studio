import AppKit
import XCTest
@testable import WalkmanStudio

final class MenuBarLyricsTests: XCTestCase {
    func testLongLineScrollsFromBeginningToEndWithHolds() {
        func offset(_ time: Double) -> CGFloat {
            MenuBarLyricText.scrollOffset(textWidth: 500, viewportWidth: 142, at: time, start: 5, end: 15)
        }
        XCTAssertEqual(offset(4), 0)
        XCTAssertEqual(offset(5), 0)
        XCTAssertEqual(offset(5.6), 0)
        XCTAssertEqual(offset(10), 179, accuracy: 0.001)
        XCTAssertEqual(offset(14.4), 358)
        XCTAssertEqual(offset(15), 358)
        XCTAssertEqual(offset(100), 358)
        // Forward and backward seeks recompute from playback position, without
        // carrying an animation's previous offset into a resumed/paused frame.
        let playbackPositions: [Double] = [5, 10, 14.4, 5, 10, 10]
        XCTAssertEqual(playbackPositions.map(offset), [0, 179, 358, 0, 179, 179])
    }

    func testShortLinesAndInvalidIntervalsDoNotScroll() {
        XCTAssertEqual(MenuBarLyricText.scrollOffset(textWidth: 90, viewportWidth: 142, at: 10, start: 0, end: 20), 0)
        XCTAssertEqual(MenuBarLyricText.scrollOffset(textWidth: 142, viewportWidth: 142, at: 10, start: 0, end: 20), 0)
        XCTAssertEqual(MenuBarLyricText.scrollOffset(textWidth: 500, viewportWidth: 142, at: 10, start: 10, end: 10), 0)
        XCTAssertEqual(MenuBarLyricText.scrollOffset(textWidth: 500, viewportWidth: 142, at: .nan, start: 0, end: 20), 0)
        XCTAssertEqual(MenuBarLyricText.scrollOffset(textWidth: .infinity, viewportWidth: 142, at: 10, start: 0, end: 20), 0)
        // Even a very short sentence window reaches its end before the next sentence.
        XCTAssertEqual(MenuBarLyricText.scrollOffset(textWidth: 500, viewportWidth: 142, at: 0.09, start: 0, end: 0.1), 358)
    }

    func testSegmentBoundariesResetScrollingAndUseTrackEnd() {
        let lines = MetadataStudioView.parseLyrics("[00:05]First\n[00:10]Second\n[00:20]Third")
        let first = MenuBarLyricText.currentSegment(in: lines, at: 9.49, duration: 30)
        XCTAssertEqual(first, .init(text: "First", start: 4.5, end: 9.5))
        let second = MenuBarLyricText.currentSegment(in: lines, at: 9.5, duration: 30)!
        XCTAssertEqual(second, .init(text: "Second", start: 9.5, end: 19.5))
        XCTAssertEqual(MenuBarLyricText.scrollOffset(textWidth: 500, viewportWidth: 142, at: 9.5, start: second.start, end: second.end), 0)
        let last = MenuBarLyricText.currentSegment(in: lines, at: 25, duration: 30)!
        XCTAssertEqual(last, .init(text: "Third", start: 19.5, end: 30))
        XCTAssertEqual(MenuBarLyricText.scrollOffset(textWidth: 500, viewportWidth: 142, at: 29.5, start: last.start, end: last.end), 358)
        XCTAssertEqual(MenuBarLyricText.currentSegment(in: lines, at: 6, duration: 30), first)
        XCTAssertEqual(MenuBarLyricText.currentSegment(in: lines, at: 25, duration: .nan)?.end, 27.5)
        XCTAssertEqual(MenuBarLyricText.currentSegment(in: lines, at: 25, duration: 10)?.end, 27.5)
    }

    func testIdenticalConsecutiveSentencesRestartAtTheirOwnTimestamp() {
        let lines = MetadataStudioView.parseLyrics("[00:00]Repeat\n[00:10]Repeat")
        let first = MenuBarLyricText.currentSegment(in: lines, at: 9, duration: 20)!
        let second = MenuBarLyricText.currentSegment(in: lines, at: 9.5, duration: 20)!
        XCTAssertEqual(first.text, second.text)
        XCTAssertEqual(MenuBarLyricText.scrollOffset(textWidth: 500, viewportWidth: 142, at: 9, start: first.start, end: first.end), 358)
        XCTAssertEqual(MenuBarLyricText.scrollOffset(textWidth: 500, viewportWidth: 142, at: 9.5, start: second.start, end: second.end), 0)
    }

    func testFallbackBeforeFirstLineAndDuringInstrumentalGap() {
        let lines = MetadataStudioView.parseLyrics("[00:05]First\n[00:10]\n[00:20]Next")
        XCTAssertNil(MenuBarLyricText.currentSegment(in: lines, at: 4, duration: 30))
        XCTAssertGreaterThan(MenuBarLyricText.fallbackScrollOffset(textWidth: 300, viewportWidth: 142, at: 4, start: 0), 0)
        let gap = MenuBarLyricText.currentSegment(in: lines, at: 13.5, duration: 30)!
        XCTAssertTrue(gap.text.isEmpty)
        XCTAssertEqual(MenuBarLyricText.fallbackScrollOffset(textWidth: 300, viewportWidth: 142, at: 9.5, start: gap.start), 0)
        XCTAssertGreaterThan(MenuBarLyricText.fallbackScrollOffset(textWidth: 300, viewportWidth: 142, at: 13.5, start: gap.start), 0)
    }

    func testDuplicateTimestampsAndBlankPassagesHaveCorrectWindows() {
        let lines = MetadataStudioView.parseLyrics("[00:00]Old\n[00:00]Current\n[00:05]\n[00:10]Next")
        XCTAssertEqual(MenuBarLyricText.currentSegment(in: lines, at: 0, duration: 20), .init(text: "Current", start: 0, end: 4.5))
        XCTAssertEqual(MenuBarLyricText.currentSegment(in: lines, at: 6, duration: 20), .init(text: "", start: 4.5, end: 9.5))
    }

    func testFallbackTitleScrollsUsingPlaybackTimeAndRepeats() {
        func offset(_ time: Double) -> CGFloat {
            MenuBarLyricText.fallbackScrollOffset(textWidth: 300, viewportWidth: 142, at: time, start: 10)
        }
        XCTAssertEqual(offset(10), 0)
        XCTAssertEqual(offset(14), 79, accuracy: 0.001)
        XCTAssertEqual(offset(17.5), 158)
        XCTAssertEqual(offset(18), 0)
        XCTAssertEqual(offset(14), offset(22))
        XCTAssertEqual(offset(10), 0)
    }

    func testChineseAndEmojiUseRenderedWidthWithoutSplittingCharacters() {
        let text = String(repeating: "歌词👨‍👩‍👧‍👦🎵", count: 10)
        let lines = MetadataStudioView.parseLyrics("[00:00]" + text)
        XCTAssertEqual(MenuBarLyricText.currentLine(in: lines, at: 5), text)
        let width = (text as NSString).size(withAttributes: [.font: MenuBarLyricText.font]).width
        XCTAssertGreaterThan(width, 142)
        XCTAssertEqual(MenuBarLyricText.scrollOffset(textWidth: width, viewportWidth: 142, at: 9.5, start: 0, end: 10), width - 142)
    }

    func testTimelineFollowsPlaybackAndBackwardSeeks() {
        let lines = MetadataStudioView.parseLyrics("[00:05.00]First\n[00:10.00]Second\n[00:20.00]Third")
        XCTAssertNil(MenuBarLyricText.currentLine(in: lines, at: 0))
        XCTAssertEqual(MenuBarLyricText.currentLine(in: lines, at: 4.5), "First")
        XCTAssertEqual(MenuBarLyricText.currentLine(in: lines, at: 9.49), "First")
        XCTAssertEqual(MenuBarLyricText.currentLine(in: lines, at: 9.5), "Second")
        XCTAssertEqual(MenuBarLyricText.currentLine(in: lines, at: 25), "Third")
        XCTAssertEqual(MenuBarLyricText.currentLine(in: lines, at: 6), "First")
        XCTAssertNil(MenuBarLyricText.currentLine(in: lines, at: 0))
    }

    func testInstrumentalGapDoesNotKeepPreviousLyric() {
        let lines = MetadataStudioView.parseLyrics("[00:00.00]First\n[00:05.00]\n[00:10.00]Second")
        XCTAssertNil(MenuBarLyricText.currentLine(in: lines, at: 6))
        XCTAssertEqual(MenuBarLyricText.currentLine(in: lines, at: 10), "Second")
    }

    func testOffsetsRepeatedTimestampsAndMixedPlainText() {
        let lines = MetadataStudioView.parseLyrics("[offset:1000]\n[00:03.00][00:15.00]Chorus\n[00:08.00]Verse\nUntimed note")
        XCTAssertNil(MenuBarLyricText.currentLine(in: lines, at: 3))
        XCTAssertEqual(MenuBarLyricText.currentLine(in: lines, at: 4), "Chorus")
        XCTAssertEqual(MenuBarLyricText.currentLine(in: lines, at: 9), "Verse")
        XCTAssertEqual(MenuBarLyricText.currentLine(in: lines, at: 16), "Chorus")
    }

    func testMissingLyricsAndInvalidProgressUseFallback() {
        XCTAssertNil(MenuBarLyricText.currentLine(in: [], at: 20))
        let lines = MetadataStudioView.parseLyrics("[00:00.00]Hello")
        XCTAssertNil(MenuBarLyricText.currentLine(in: lines, at: .nan))
        XCTAssertNil(MenuBarLyricText.currentLine(in: lines, at: .infinity))
    }

    func testPlainLyricsFollowExistingEstimatedTimeline() {
        let lines = MetadataStudioView.parseLyrics("First\nSecond", durationSeconds: 60)
        XCTAssertNil(MenuBarLyricText.currentLine(in: lines, at: 0))
        XCTAssertEqual(MenuBarLyricText.currentLine(in: lines, at: 3), "First")
        XCTAssertEqual(MenuBarLyricText.currentLine(in: lines, at: 40), "Second")
    }
}
