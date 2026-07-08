import Foundation

enum L10n {
    private static let chineseBundle: Bundle = {
        guard let path = Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }()

    static func text(_ key: String, fallback: String) -> String {
        chineseBundle.localizedString(forKey: key, value: fallback, table: nil)
    }

    static func format(_ key: String, fallback: String, _ arguments: CVarArg...) -> String {
        String(format: text(key, fallback: fallback), arguments: arguments)
    }
}
