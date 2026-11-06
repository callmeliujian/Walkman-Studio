import Foundation
import Combine

/// Stable preference values, independent of the translated labels shown in the UI.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L10n.tr("Follow System")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }

    func resolvedIdentifier(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        guard self == .system else { return rawValue }
        return preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? "zh-Hans" : "en"
    }
}

final class AppLocalization: ObservableObject {
    static let preferenceKey = "WalkmanStudio.interfaceLanguage"
    static let shared = AppLocalization()

    private let defaults: UserDefaults
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Self.preferenceKey) }
    }

    var locale: Locale { Locale(identifier: language.resolvedIdentifier()) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: Self.preferenceKey) ?? "") ?? .system
    }
}

/// Keeps interpolated user data out of translation keys and permits argument reordering.
struct LocalizedMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    let key: String
    let arguments: [String]

    init(stringLiteral value: String) {
        key = value
        arguments = []
    }

    init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key
        arguments = stringInterpolation.arguments
    }

    struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []

        init(literalCapacity: Int, interpolationCount: Int) {
            key.reserveCapacity(literalCapacity)
            arguments.reserveCapacity(interpolationCount)
        }

        mutating func appendLiteral(_ literal: String) { key += literal }

        mutating func appendInterpolation<T>(_ value: T) {
            key += "{\(arguments.count)}"
            arguments.append(String(describing: value))
        }
    }
}

enum L10n {
    private static let placeholderRegex = try! NSRegularExpression(pattern: #"\{(\d+)\}"#)

    static let chineseTranslations: [String: String] = {
        // Packaged .app builds keep resources in Contents/Resources. SwiftPM runs
        // and tests use Bundle.module. Neither path depends on the working directory.
        let url = Bundle.main.url(forResource: "zh-Hans", withExtension: "json", subdirectory: "Localization")
            ?? Bundle.module.url(forResource: "zh-Hans", withExtension: "json", subdirectory: "Localization")
        guard let url, let data = try? Data(contentsOf: url),
              let translations = try? JSONDecoder().decode([String: String].self, from: data) else {
            assertionFailure("Missing or invalid Chinese localization catalog")
            return [:]
        }
        return translations
    }()

    static var currentLanguage: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: AppLocalization.preferenceKey) ?? "") ?? .system
    }

    static func tr(_ message: LocalizedMessage, language: AppLanguage = currentLanguage) -> String {
        let template = lookup(message.key, language: language)
        // Substitute in one pass: text such as "{1}" inside a song title must
        // never be interpreted as another localization placeholder.
        guard !message.arguments.isEmpty else { return template }
        var result = template
        let matches = placeholderRegex.matches(in: template, range: NSRange(template.startIndex..., in: template))
        for match in matches.reversed() {
            guard let indexRange = Range(match.range(at: 1), in: template),
                  let index = Int(template[indexRange]), message.arguments.indices.contains(index),
                  let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: message.arguments[index])
        }
        return result
    }

    /// Only use for known UI keys (such as enum display labels), never music metadata.
    static func lookup(_ key: String, language: AppLanguage = currentLanguage) -> String {
        language.resolvedIdentifier() == "zh-Hans" ? (chineseTranslations[key] ?? key) : key
    }

    static func pluralSuffix(_ count: Int) -> String {
        currentLanguage.resolvedIdentifier() == "zh-Hans" || count == 1 ? "" : "s"
    }
}
