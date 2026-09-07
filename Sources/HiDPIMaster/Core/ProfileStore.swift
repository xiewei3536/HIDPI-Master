import Foundation
import Combine
import ServiceManagement

extension Notification.Name {
    static let hidpiProfilesChanged = Notification.Name("HiDPIMaster.profilesChanged")
}

final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    struct VirtualConfig: Codable {
        var width: Int
        var height: Int
    }

    /// Plain-language size preference that biases every recommendation.
    enum SizePreference: String, CaseIterable, Identifiable {
        case larger, balanced, space
        var id: String { rawValue }
        var labelKey: String { "pref." + rawValue }
        /// Shift applied to the comfortable UI density target (PPI).
        var ppiBias: Double {
            switch self {
            case .larger: return -14
            case .balanced: return 0
            case .space: return 14
            }
        }
    }

    private let defaults = UserDefaults.standard

    /// True only for the very first launch of the app on this Mac.
    let isFirstLaunch: Bool

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

    @Published var sizePreference: SizePreference {
        didSet { defaults.set(sizePreference.rawValue, forKey: "reco.sizePreference") }
    }

    private init() {
        isFirstLaunch = !defaults.bool(forKey: "app.hasLaunched")
        defaults.set(true, forKey: "app.hasLaunched")
        autoApply = defaults.object(forKey: "profiles.autoApply") as? Bool ?? true
        advancedMode = defaults.object(forKey: "ui.advancedMode") as? Bool ?? false
        autoCheckUpdates = defaults.object(forKey: "update.autoCheck") as? Bool ?? true
        sizePreference = SizePreference(rawValue: defaults.string(forKey: "reco.sizePreference") ?? "") ?? .balanced
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            launchAtLogin = false
        }
    }

    private func notifyChanged() {
        objectWillChange.send()
        NotificationCenter.default.post(name: .hidpiProfilesChanged, object: nil)
    }

    // MARK: - Update prompts

    var lastPromptedUpdateVersion: String? {
        get { defaults.string(forKey: "update.lastPrompted") }
        set { defaults.set(newValue, forKey: "update.lastPrompted") }
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

    // MARK: - Trusted modes (confirmed once via keep/revert countdown)

    private var trustedModes: [String: [String]] {
        get { defaults.dictionary(forKey: "profiles.trusted") as? [String: [String]] ?? [:] }
        set { defaults.set(newValue, forKey: "profiles.trusted") }
    }

    func isTrusted(_ modeID: String, for key: String) -> Bool {
        trustedModes[key]?.contains(modeID) ?? false
    }

    func trust(_ modeID: String, for key: String) {
        var t = trustedModes
        var list = t[key] ?? []
        if !list.contains(modeID) { list.append(modeID) }
        t[key] = list
        trustedModes = t
    }

    // MARK: - Manual screen size corrections

    private var manualDiagonals: [String: Double] {
        get { defaults.dictionary(forKey: "display.manualDiagonal") as? [String: Double] ?? [:] }
        set { defaults.set(newValue, forKey: "display.manualDiagonal") }
    }

    func manualDiagonal(for key: String) -> Double? {
        manualDiagonals[key]
    }

    func setManualDiagonal(_ inches: Double?, for key: String) {
        var m = manualDiagonals
        m[key] = inches
        manualDiagonals = m
        notifyChanged()
    }

    // MARK: - Apply-after-reboot wishes (Intel override flow)

    private var pending: [String: VirtualConfig] {
        get { decode("profiles.pending") }
        set { encode(newValue, "profiles.pending") }
    }

    func pendingLooksLike(for key: String) -> VirtualConfig? { pending[key] }

    func setPendingLooksLike(_ config: VirtualConfig?, for key: String) {
        var p = pending
        p[key] = config
        pending = p
    }

    // MARK: - Virtual display configs (Apple Silicon path)

    private var virtualConfigs: [String: VirtualConfig] {
        get { decode("profiles.virtual") }
        set { encode(newValue, "profiles.virtual") }
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

    private func decode(_ key: String) -> [String: VirtualConfig] {
        guard let data = defaults.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: VirtualConfig].self, from: data)
        else { return [:] }
        return dict
    }

    private func encode(_ value: [String: VirtualConfig], _ key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    func resetAll() {
        for key in ["profiles.modes", "profiles.virtual", "profiles.trusted",
                    "profiles.pending", "display.manualDiagonal"] {
            defaults.removeObject(forKey: key)
        }
        notifyChanged()
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
