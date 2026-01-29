import Foundation

class UserPreferences {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let lastSelectedModel = "lastSelectedModel"
        static let isDarkModeEnabled = "isDarkModeEnabled"
        static let fontSize = "fontSize"
    }

    func saveLastSelectedModel(_ model: String) {
        defaults.set(model, forKey: Keys.lastSelectedModel)
    }

    func getLastSelectedModel() -> String? {
        return defaults.string(forKey: Keys.lastSelectedModel)
    }

    func setDarkMode(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.isDarkModeEnabled)
    }

    func isDarkModeEnabled() -> Bool {
        return defaults.bool(forKey: Keys.isDarkModeEnabled)
    }

    func saveFontSize(_ size: Float) {
        defaults.set(size, forKey: Keys.fontSize)
    }

    func getFontSize() -> Float {
        return defaults.float(forKey: Keys.fontSize)
    }
}
