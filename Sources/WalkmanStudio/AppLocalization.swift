import Foundation
import Combine

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
