import Foundation
import AppKit
import CoreGraphics
import Combine

final class DisplayManager: ObservableObject {
    static let shared = DisplayManager()

    @Published private(set) var displays: [DisplayInfo] = []

    private var observer: Any?
    private var debounce: DispatchWorkItem?

    private init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduleRefresh()
        }
    }

    private func scheduleRefresh() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refresh()
            self?.autoApplyIfNeeded()
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
            // Skip our own virtual displays (they are represented through the panel card)
            if VirtualDisplayController.shared.isVirtualDisplay(id) { continue }
            result.append(info(for: id))
        }
        // Built-in first, then externals
        result.sort { a, b in
            if a.isBuiltin != b.isBuiltin { return a.isBuiltin }
            return a.id < b.id
        }
        displays = result
    }

    private func info(for id: CGDirectDisplayID) -> DisplayInfo {
        let options = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
        var modeInfos: [ModeInfo] = []
        if let all = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode] {
            var best: [String: ModeInfo] = [:]
            for m in all where m.isUsableForDesktopGUI() {
                let mi = ModeInfo(mode: m)
                // Keep every distinct refresh rate (id includes Hz)
                best[mi.id] = mi
            }
            modeInfos = Array(best.values).sorted {
                if $0.width != $1.width { return $0.width > $1.width }
                if $0.height != $1.height { return $0.height > $1.height }
                if $0.pixelWidth != $1.pixelWidth { return $0.pixelWidth > $1.pixelWidth }
                return $0.refreshRate > $1.refreshRate
            }
        }

        let current = CGDisplayCopyDisplayMode(id).map(ModeInfo.init)
        // Prefer the mode the driver flags as panel-native (0x02000000):
        // robust against oversized scaled modes injected by an installed
        // override. Fall back to the largest pixel dimensions.
        let nativeMode = modeInfos.first { $0.mode.ioFlags & 0x02000000 != 0 }
        let nativeW = nativeMode?.pixelWidth
            ?? modeInfos.map(\.pixelWidth).max() ?? (current?.pixelWidth ?? 0)
        let nativeH = nativeMode?.pixelHeight
            ?? modeInfos.map(\.pixelHeight).max() ?? (current?.pixelHeight ?? 0)

        var name = L(CGDisplayIsBuiltin(id) != 0 ? "display.builtin" : "display.external")
        for screen in NSScreen.screens {
            if let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               n.uint32Value == id {
                if #available(macOS 10.15, *) { name = screen.localizedName }
            }
        }

        return DisplayInfo(
            id: id,
            name: name,
            isBuiltin: CGDisplayIsBuiltin(id) != 0,
            vendorID: CGDisplayVendorNumber(id),
            productID: CGDisplayModelNumber(id),
            physicalSize: CGDisplayScreenSize(id),
            nativePixelWidth: nativeW,
            nativePixelHeight: nativeH,
            currentMode: current,
            modes: modeInfos,
            mirrorsDisplayID: CGDisplayMirrorsDisplay(id)
        )
    }

    // MARK: - Mode switching

    @discardableResult
    func apply(mode: ModeInfo, to display: DisplayInfo, remember: Bool = true) -> Bool {
        // If this display mirrors one of our virtual displays, the resolution
        // must be changed on the virtual display instead.
        if VirtualDisplayController.shared.isVirtualDisplay(display.mirrorsDisplayID) {
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

    func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refresh()
        }
    }

    // MARK: - Auto apply saved profiles

    func autoApplyIfNeeded() {
        guard ProfileStore.shared.autoApply else { return }
        for d in displays where !d.isBuiltin {
            // Recreate virtual HiDPI displays saved for this panel (Apple Silicon path)
            if let vcfg = ProfileStore.shared.virtualConfig(for: d.persistentKey),
               !VirtualDisplayController.shared.isVirtualDisplay(d.mirrorsDisplayID) {
                try? VirtualDisplayController.shared.enableHiDPI(
                    for: d,
                    primaryLooksLike: (vcfg.width, vcfg.height)
                )
                continue
            }
            if let savedID = ProfileStore.shared.rememberedMode(for: d.persistentKey),
               let target = d.modes.first(where: { $0.id == savedID }),
               d.currentMode?.id != savedID {
                apply(mode: target, to: d, remember: false)
            }
        }
    }
}
