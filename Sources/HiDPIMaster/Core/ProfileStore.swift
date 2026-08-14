import Foundation
import Combine
import ServiceManagement

final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    struct VirtualConfig: Codable {
        var width: Int
        var height: Int
    }

    private let defaults = UserDefaults.standard

    @Published var autoApply: Bool {
        didSet { defaults.set(autoApply, forKey: "profiles.autoApply") }
    }

    /// Advanced mode shows resolutions/PPI numbers; simple mode (default)
    /// uses friendly "bigger text ↔ smaller text" wording only.
    @Published var advancedMode: Bool {
        didSet { defaults.set(advancedMode, forKey: "ui.advancedMode") }
    }

    @Published var launchAtLogin: Bool {
        didSet { updateLaunchAtLogin() }
    }

    @Published var autoCheckUpdates: Bool {
        didSet { defaults.set(autoCheckUpdates, forKey: "update.autoCheck") }
    }

    private init() {
        autoApply = defaults.object(forKey: "profiles.autoApply") as? Bool ?? true
        advancedMode = defaults.object(forKey: "ui.advancedMode") as? Bool ?? false
        autoCheckUpdates = defaults.object(forKey: "update.autoCheck") as? Bool ?? true
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            launchAtLogin = false
        }
    }

    // MARK: - Remembered display modes

    private var rememberedModes: [String: String] {
        get { defaults.dictionary(forKey: "profiles.modes") as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: "profiles.modes") }
    }

    func rememberMode(_ modeID: String, for key: String) {
        var m = rememberedModes
        m[key] = modeID
        rememberedModes = m
    }

    func rememberedMode(for key: String) -> String? {
        rememberedModes[key]
    }

    // MARK: - Virtual display configs (Apple Silicon path)

    private var virtualConfigs: [String: VirtualConfig] {
        get {
            guard let data = defaults.data(forKey: "profiles.virtual"),
                  let dict = try? JSONDecoder().decode([String: VirtualConfig].self, from: data)
            else { return [:] }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "profiles.virtual")
            }
        }
    }

    func virtualConfig(for key: String) -> VirtualConfig? {
        virtualConfigs[key]
    }

    func setVirtualConfig(_ config: VirtualConfig?, for key: String) {
        var v = virtualConfigs
        v[key] = config
        virtualConfigs = v
        objectWillChange.send()
    }

    func resetAll() {
        defaults.removeObject(forKey: "profiles.modes")
        defaults.removeObject(forKey: "profiles.virtual")
        objectWillChange.send()
    }

    // MARK: - Launch at login

    var supportsLaunchAtLogin: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    private func updateLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Launch at login toggle failed: \(error)")
        }
    }
}
