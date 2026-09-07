import Foundation
import Combine

/// Runtime-switchable localization. Supports: auto / en / zh-Hant / zh-Hans
final class L10n: ObservableObject {
    static let shared = L10n()

    static let supported: [(code: String, nameKey: String)] = [
        ("auto", "settings.language.auto"),
        ("en", "English"),
        ("zh-Hant", "繁體中文"),
        ("zh-Hans", "简体中文"),
    ]

    @Published var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: "app.language")
            reload()
        }
    }

    private var bundle: Bundle = .module

    private init() {
        language = UserDefaults.standard.string(forKey: "app.language") ?? "auto"
        reload()
    }

    private var resolvedCode: String {
        if language != "auto" { return language }
        for pref in Locale.preferredLanguages {
            let p = pref.lowercased()
            if p.hasPrefix("zh") {
                if p.contains("hant") || p.contains("tw") || p.contains("hk") || p.contains("mo") {
                    return "zh-Hant"
                }
                return "zh-Hans"
            }
            if p.hasPrefix("en") { return "en" }
        }
        return "en"
    }

    private func reload() {
        let code = resolvedCode
        // SPM may lowercase .lproj folder names; try both spellings.
        if let path = Bundle.module.path(forResource: code, ofType: "lproj")
            ?? Bundle.module.path(forResource: code.lowercased(), ofType: "lproj"),
           let b = Bundle(path: path) {
            bundle = b
        } else {
            bundle = .module
        }
        objectWillChange.send()
        NotificationCenter.default.post(name: .hidpiLanguageChanged, object: nil)
    }

    func t(_ key: String) -> String {
        let s = bundle.localizedString(forKey: key, value: nil, table: nil)
        return s == key ? key : s
    }

    func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }
}

/// Shorthand
func L(_ key: String) -> String { L10n.shared.t(key) }
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L10n.shared.t(key), arguments: args)
}
