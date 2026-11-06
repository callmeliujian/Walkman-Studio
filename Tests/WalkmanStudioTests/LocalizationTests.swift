import XCTest
@testable import WalkmanStudio

final class LocalizationTests: XCTestCase {
    func testSystemLanguageResolutionAndExplicitOverride() {
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredLanguages: ["zh-CN", "en"]), "zh-Hans")
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredLanguages: ["zh-Hant-TW"]), "zh-Hans")
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredLanguages: ["fr", "zh-Hans"]), "en")
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredLanguages: []), "en")
        XCTAssertEqual(AppLanguage.english.resolvedIdentifier(preferredLanguages: ["zh-Hans"]), "en")
        XCTAssertEqual(AppLanguage.simplifiedChinese.resolvedIdentifier(preferredLanguages: ["en"]), "zh-Hans")
    }

    func testPreferenceSurvivesRelaunchAndInvalidValuesFallBack() {
        let name = "WalkmanStudioTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppLocalization(defaults: defaults)
        XCTAssertEqual(settings.language, .system)
        settings.language = .simplifiedChinese
        XCTAssertEqual(AppLocalization(defaults: defaults).language, .simplifiedChinese)
        settings.language = .english
        XCTAssertEqual(AppLocalization(defaults: defaults).language, .english)
        settings.language = .system
        XCTAssertEqual(AppLocalization(defaults: defaults).language, .system)
        defaults.set("unsupported", forKey: AppLocalization.preferenceKey)
        XCTAssertEqual(AppLocalization(defaults: defaults).language, .system)
    }

    func testTranslationAndEnglishFallback() {
        XCTAssertEqual(L10n.tr("About Walkman Studio", language: .simplifiedChinese), "关于 Walkman Studio")
        XCTAssertEqual(L10n.tr("About Walkman Studio", language: .english), "About Walkman Studio")
        XCTAssertEqual(L10n.tr("Untranslated new label", language: .simplifiedChinese), "Untranslated new label")
        XCTAssertEqual(L10n.tr("\(0) tracks", language: .simplifiedChinese), "0 首曲目")
        XCTAssertEqual(L10n.tr("\(1) tracks", language: .simplifiedChinese), "1 首曲目")
        XCTAssertEqual(L10n.tr("\(42) tracks", language: .english), "42 tracks")
    }

    func testInterpolationPreservesUserDataAndSupportsReordering() {
        let name = "歌曲 {1} %@ \\ path 🎵"
        let message: LocalizedMessage = "\(3) tracks in playlist '\(name)'"
        XCTAssertEqual(L10n.tr(message, language: .simplifiedChinese), "播放列表“\(name)”中有 3 首曲目")
        XCTAssertEqual(L10n.tr(message, language: .english), "3 tracks in playlist '\(name)'")
        let missing: LocalizedMessage = "New message \(name): \(7)"
        XCTAssertEqual(L10n.tr(missing, language: .simplifiedChinese), "New message \(name): 7")
    }

    func testEveryTranslationPreservesItsPlaceholders() throws {
        XCTAssertGreaterThan(L10n.chineseTranslations.count, 1400)
        let regex = try NSRegularExpression(pattern: #"\{\d+\}"#)
        func placeholders(_ value: String) -> [String] {
            regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).map {
                String(value[Range($0.range, in: value)!])
            }.sorted()
        }
        for (key, translation) in L10n.chineseTranslations {
            XCTAssertFalse(translation.isEmpty, key)
            XCTAssertEqual(placeholders(key), placeholders(translation), key)
        }
    }

    func testNavigationIdentifiersAndChannelDataStayStable() {
        XCTAssertEqual(NavigationTab.localLibrary.rawValue, "Local Music Library")
        XCTAssertEqual(LocalDisplayMode.songs.rawValue, "Songs")
        let channel = SenseMeChannel.allChannels[0]
        XCTAssertEqual(channel.id, "morning")
        XCTAssertEqual(channel.name, "Morning")
        XCTAssertEqual(L10n.lookup(channel.name, language: .simplifiedChinese), "清晨")
        XCTAssertEqual(L10n.lookup(channel.name, language: .english), "Morning")
        XCTAssertEqual(L10n.lookup(channel.subtitle, language: .simplifiedChinese), "05:00 – 10:00 • 清新轻快")
    }
}
