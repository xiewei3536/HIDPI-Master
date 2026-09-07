import Foundation
import AppKit
import CoreGraphics
import Combine

extension Notification.Name {
    static let hidpiLanguageChanged = Notification.Name("HiDPIMaster.languageChanged")
}

final class DisplayManager: ObservableObject {
    static let shared = DisplayManager()

    @Published private(set) var displays: [DisplayInfo] = []

    private var observers: [Any] = []
    private var debounce: DispatchWorkItem?
    private var knownKeys = Set<String>()
    /// Set while a keep/revert countdown is running so auto-apply never fights it.
    private(set) var isConfirming = false

    private init() {
        refresh()
        knownKeys = Set(displays.map(\.persistentKey))
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                        object: nil, queue: .main) { [weak self] _ in
            self?.scheduleRefresh()
        })
        observers.append(nc.addObserver(forName: .hidpiLanguageChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        })
        observers.append(nc.addObserver(forName: .hidpiProfilesChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        })
    }

    /// Debounced refresh after a screen change. Saved setups are re-applied
    /// only for displays that (re)appeared, never for mere mode changes —
    /// otherwise changes made in System Settings would be fought.
    private func scheduleRefresh() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let before = self.knownKeys
            self.refresh()
            let now = Set(self.displays.map(\.persistentKey))
            self.knownKeys = now
            let added = now.subtracting(before)
            if !added.isEmpty {
                self.autoApplyIfNeeded(onlyKeys: added)
            }
        }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    // MARK: - Enumeration

    func refresh() {
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        CGGetOnlineDisplayList(16, &ids, &count)
        let online = Array(ids.prefix(Int(count)))

        var result: [DisplayInfo] = []
        for id in online {
            // Our own virtual displays are represented through the panel card
            if VirtualDisplayController.shared.isVirtualDisplay(id) { continue }
            result.append(info(for: id))
        }
        result.sort { a, b in
            if a.isBuiltin != b.isBuiltin { return a.isBuiltin }
            return a.id < b.id
        }
        displays = result
    }

    private func enumerateModes(_ id: CGDirectDisplayID) -> [ModeInfo] {
        let options = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
        guard let all = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode] else { return [] }
        // The active mode is always listed, even when macOS flags it as not
        // "usable for desktop GUI" (e.g. a HiDPI timing the monitor downscales).
        let current = CGDisplayCopyDisplayMode(id)
        var unique: [String: ModeInfo] = [:]
        for m in all where m.isUsableForDesktopGUI() || m.ioDisplayModeID == current?.ioDisplayModeID {
            let mi = ModeInfo(mode: m)
            unique[mi.id] = mi
        }
        if let cur = current {
            let mi = ModeInfo(mode: cur)
            if unique[mi.id] == nil { unique[mi.id] = mi }
        }
        return Array(unique.values).sorted {
            if $0.width != $1.width { return $0.width > $1.width }
            if $0.height != $1.height { return $0.height > $1.height }
            if $0.pixelWidth != $1.pixelWidth { return $0.pixelWidth > $1.pixelWidth }
            return $0.refreshRate > $1.refreshRate
        }
    }

    private func info(for id: CGDirectDisplayID) -> DisplayInfo {
        let physicalModes = enumerateModes(id)
        let mirrorTarget = CGDisplayMirrorsDisplay(id)
        let isVirtualMirror = VirtualDisplayController.shared.isVirtualDisplay(mirrorTarget)
        // When mirrored onto our virtual display, the selectable modes live there.
        let modeSource = isVirtualMirror ? mirrorTarget : id
        let modes = isVirtualMirror ? enumerateModes(modeSource) : physicalModes
        let current = CGDisplayCopyDisplayMode(modeSource).map(ModeInfo.init)

        // Prefer the mode flagged as panel-native (0x02000000); robust against
        // oversized scaled modes injected by an override.
        let nativeMode = physicalModes.first { $0.mode.ioFlags & 0x02000000 != 0 }
        let nativeW = nativeMode?.pixelWidth
            ?? physicalModes.map(\.pixelWidth).max() ?? (current?.pixelWidth ?? 0)
        let nativeH = nativeMode?.pixelHeight
            ?? physicalModes.map(\.pixelHeight).max() ?? (current?.pixelHeight ?? 0)

        let isBuiltin = CGDisplayIsBuiltin(id) != 0
        var name = L(isBuiltin ? "display.builtin" : "display.external")
        for screen in NSScreen.screens {
            if let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               n.uint32Value == id {
                name = screen.localizedName
            }
        }

        let vendor = CGDisplayVendorNumber(id)
        let product = CGDisplayModelNumber(id)
        let serial = CGDisplaySerialNumber(id)
        let key = DisplayInfo.makeKey(vendorID: vendor, productID: product, serialNumber: serial,
                                      nativeW: nativeW, nativeH: nativeH)

        return DisplayInfo(
            id: id,
            name: name,
            isBuiltin: isBuiltin,
            vendorID: vendor,
            productID: product,
            serialNumber: serial,
            physicalSize: CGDisplayScreenSize(id),
            nativePixelWidth: nativeW,
            nativePixelHeight: nativeH,
            currentMode: current,
            modes: modes,
            mirrorsDisplayID: mirrorTarget,
            isVirtualMirror: isVirtualMirror,
            manualDiagonalInches: ProfileStore.shared.manualDiagonal(for: key)
        )
    }

    // MARK: - Mode switching (low level)

    @discardableResult
    func apply(mode: ModeInfo, to display: DisplayInfo, remember: Bool = true) -> Bool {
        if display.isVirtualMirror {
            let ok = VirtualDisplayController.shared.setMode(
                virtualID: display.mirrorsDisplayID,
                looksLikeWidth: mode.width, looksLikeHeight: mode.height
            )
            if ok, remember {
                ProfileStore.shared.rememberMode(mode.id, for: display.persistentKey)
            }
            refreshSoon()
            return ok
        }

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return false }
        CGConfigureDisplayWithDisplayMode(config, display.id, mode.mode, nil)
        let err = CGCompleteDisplayConfiguration(config, .permanently)
        if err == .success {
            if remember {
                ProfileStore.shared.rememberMode(mode.id, for: display.persistentKey)
            }
            refreshSoon()
            return true
        }
        return false
    }

    // MARK: - Safe switching (keep / revert countdown)

    /// Applies a mode; risky switches (refresh-rate change, non-HiDPI mode or
    /// aspect mismatch) that were never confirmed before get a countdown
    /// dialog and revert automatically if nobody answers.
    /// Must be called on the main thread. Returns true when the mode stays.
    @discardableResult
    func applySafely(mode: ModeInfo, to display: DisplayInfo) -> Bool {
        guard let previous = display.currentMode else {
            return apply(mode: mode, to: display)
        }
        if previous.id == mode.id { return true }

        let fits = display.fitsPanelAspect(width: mode.width, height: mode.height)
        if !fits, !Alerts.confirmAspectMismatch() { return false }

        let hzChanged = abs(previous.refreshRate - mode.refreshRate) > 0.5
        let risky = hzChanged || !mode.isHiDPI || !fits
        let key = display.persistentKey
        let needsConfirm = risky && !ProfileStore.shared.isTrusted(mode.id, for: key)

        guard apply(mode: mode, to: display, remember: !needsConfirm) else {
            Alerts.error(L("err.applyFailed"), L("err.applyFailedMsg"))
            return false
        }
        guard needsConfirm else { return true }

        isConfirming = true
        let keep = Alerts.confirmKeep(seconds: 12)
        isConfirming = false
        if keep {
            ProfileStore.shared.trust(mode.id, for: key)
            ProfileStore.shared.rememberMode(mode.id, for: key)
            return true
        }
        apply(mode: previous, to: display, remember: false)
        return false
    }

    func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refresh()
        }
    }

    // MARK: - One-click optimize

    func isOptimal(_ display: DisplayInfo) -> Bool {
        guard let top = RecommendationEngine.recommend(for: display).first,
              let mode = top.mode else { return true }
        return display.currentMode?.resolutionKey == mode.resolutionKey
    }

    var externalDisplays: [DisplayInfo] { displays.filter { !$0.isBuiltin } }

    var needsOptimization: Bool {
        externalDisplays.contains { !$0.sizeUnknown && !isOptimal($0) }
    }

    /// HiDPI modes exist right now but no override file backs them (Intel,
    /// sub-4K panel): they may vanish or shrink after the next reboot.
    func needsPersistence(_ d: DisplayInfo) -> Bool {
        !SystemInfo.isAppleSilicon && !d.isBuiltin && !d.isVirtualMirror && d.hasHiDPIModes
            && d.nativePixelWidth < 3840 && !EDIDOverrideInstaller.isInstalled(for: d)
    }

    /// Anything the card is currently asking the user to look at.
    func needsAttention(_ d: DisplayInfo) -> Bool {
        d.sizeUnknown || (!d.hasHiDPIModes && !d.isVirtualMirror) || needsPersistence(d) || !isOptimal(d)
    }

    var allExternalsGood: Bool {
        !externalDisplays.isEmpty && !externalDisplays.contains { needsAttention($0) }
    }

    func optimizeAll() {
        for d in externalDisplays where !d.sizeUnknown && !isOptimal(d) {
            if let mode = RecommendationEngine.recommend(for: d).first?.mode {
                applySafely(mode: d.variantKeepingRefresh(of: mode), to: d)
            }
        }
        refreshSoon()
    }

    // MARK: - Auto apply saved profiles

    /// Re-applies saved setups. `onlyKeys` restricts this to displays that just
    /// (re)appeared; nil means all (used at launch).
    func autoApplyIfNeeded(onlyKeys: Set<String>? = nil) {
        guard ProfileStore.shared.autoApply, !isConfirming else { return }
        let store = ProfileStore.shared
        for d in displays where !d.isBuiltin {
            let key = d.persistentKey
            if let only = onlyKeys, !only.contains(key) { continue }

            // 1. Wish recorded before a reboot (Intel override flow)
            if let pending = store.pendingLooksLike(for: key),
               let rep = d.uniqueHiDPIModes.first(where: { $0.width == pending.width && $0.height == pending.height }) {
                let target = d.variantKeepingRefresh(of: rep)
                if apply(mode: target, to: d, remember: true) {
                    store.trust(target.id, for: key)
                }
                store.setPendingLooksLike(nil, for: key)
                continue
            }

            // 2. Recreate a virtual HiDPI display saved for this panel
            if let vcfg = store.virtualConfig(for: key), !d.isVirtualMirror {
                try? VirtualDisplayController.shared.enableHiDPI(
                    for: d, primaryLooksLike: (vcfg.width, vcfg.height))
                continue
            }

            // 3. Remembered mode: exact (incl. Hz), else same resolution at best Hz
            if let savedID = store.rememberedMode(for: key), d.currentMode?.id != savedID {
                if let exact = d.modes.first(where: { $0.id == savedID }) {
                    apply(mode: exact, to: d, remember: false)
                } else {
                    let resKey = savedID.split(separator: "@").dropLast().joined(separator: "@")
                    if let rep = d.modes.first(where: { $0.resolutionKey == resKey }) {
                        apply(mode: d.variantKeepingRefresh(of: rep), to: d, remember: false)
                    }
                }
            }
        }
    }

    /// Called on quit: release virtual displays but keep their configs so the
    /// next launch restores them.
    func teardownForQuit() {
        VirtualDisplayController.shared.teardownAll(keepConfig: true)
    }
}
