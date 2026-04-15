import Foundation

/// Persistent app-wide settings backed by UserDefaults.
final class AppSettings {
    static let shared = AppSettings()
    private init() {}

    private func bool(_ key: String, default def: Bool = true) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? def
    }

    var bgmEnabled: Bool {
        get { bool("bgmEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "bgmEnabled") }
    }
    var sfxEnabled: Bool {
        get { bool("sfxEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "sfxEnabled") }
    }
    var hapticsEnabled: Bool {
        get { bool("hapticsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "hapticsEnabled") }
    }
    var ghostEnabled: Bool {
        get { bool("ghostEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "ghostEnabled") }
    }
}
