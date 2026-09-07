import Foundation
import CoreGraphics

/// One selectable display mode. Identity includes refresh rate, so every
/// selectable Hz is its own entry; `resolutionKey` ignores Hz.
struct ModeInfo: Identifiable, Hashable {
    let mode: CGDisplayMode
    let width: Int          // points ("looks like")
    let height: Int
    let pixelWidth: Int     // backing pixels
    let pixelHeight: Int
    let refreshRate: Double

    var isHiDPI: Bool { pixelWidth > width }
    var scale: Double { width > 0 ? Double(pixelWidth) / Double(width) : 1 }

    var id: String { "\(resolutionKey)@\(Int(refreshRate.rounded()))" }
    var resolutionKey: String { "\(width)x\(height)@\(pixelWidth)x\(pixelHeight)" }

    static func == (lhs: ModeInfo, rhs: ModeInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(mode: CGDisplayMode) {
        self.mode = mode
        self.width = mode.width
        self.height = mode.height
        self.pixelWidth = mode.pixelWidth
        self.pixelHeight = mode.pixelHeight
        self.refreshRate = mode.refreshRate
    }
}

struct DisplayInfo: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltin: Bool
    let vendorID: UInt32
    let productID: UInt32
    let serialNumber: UInt32
    let physicalSize: CGSize        // millimeters as reported by EDID (may be bogus)
    let nativePixelWidth: Int
    let nativePixelHeight: Int
    let currentMode: ModeInfo?
    let modes: [ModeInfo]           // sorted large → small (all Hz variants)
    let mirrorsDisplayID: CGDirectDisplayID
    /// True when this panel mirrors one of our virtual HiDPI displays; in that
    /// case `modes`/`currentMode` describe the virtual display.
    let isVirtualMirror: Bool
    /// User-corrected diagonal (inches) when EDID size is missing or wrong.
    let manualDiagonalInches: Double?

    // MARK: Identity

    static func makeKey(vendorID: UInt32, productID: UInt32, serialNumber: UInt32,
                        nativeW: Int, nativeH: Int) -> String {
        if vendorID == 0 && productID == 0 { return "generic-\(nativeW)x\(nativeH)" }
        var key = "\(vendorID)-\(productID)"
        if serialNumber != 0 { key += "-\(serialNumber)" }
        return key
    }

    /// Stable key across reconnects/reboots for saving profiles.
    var persistentKey: String {
        Self.makeKey(vendorID: vendorID, productID: productID, serialNumber: serialNumber,
                     nativeW: nativePixelWidth, nativeH: nativePixelHeight)
    }

    // MARK: Physical size

    var detectedDiagonalInches: Double {
        let w = physicalSize.width, h = physicalSize.height
        guard w > 0, h > 0 else { return 0 }
        return (w * w + h * h).squareRoot() / 25.4
    }

    /// Best-known diagonal: manual correction first, then a plausible EDID value.
    var diagonalInches: Double {
        if let m = manualDiagonalInches, m > 0 { return m }
        let d = detectedDiagonalInches
        return (d >= 8 && d <= 110) ? d : 0
    }

    var sizeUnknown: Bool { diagonalInches == 0 }

    var ppi: Double {
        guard diagonalInches > 0 else { return 0 }
        let dw = Double(nativePixelWidth), dh = Double(nativePixelHeight)
        return (dw * dw + dh * dh).squareRoot() / diagonalInches
    }

    // MARK: Mode helpers

    var hasHiDPIModes: Bool { modes.contains { $0.isHiDPI } }

    var hiDPIModes: [ModeInfo] { modes.filter { $0.isHiDPI } }

    /// One representative per resolution/density pair (the highest-Hz variant).
    var uniqueResolutionModes: [ModeInfo] {
        var seen = Set<String>()
        return modes.filter { seen.insert($0.resolutionKey).inserted }
    }

    var uniqueHiDPIModes: [ModeInfo] { uniqueResolutionModes.filter { $0.isHiDPI } }

    /// All selectable refresh rates for a given resolution, highest first.
    func refreshVariants(of mode: ModeInfo) -> [ModeInfo] {
        modes.filter { $0.resolutionKey == mode.resolutionKey }
            .sorted { $0.refreshRate > $1.refreshRate }
    }

    /// Best variant of `rep` when switching resolution: keep the current
    /// refresh rate when the new resolution offers it, otherwise the highest.
    func variantKeepingRefresh(of rep: ModeInfo) -> ModeInfo {
        let variants = refreshVariants(of: rep)
        if let cur = currentMode,
           let exact = variants.first(where: { abs($0.refreshRate - cur.refreshRate) < 0.5 }) {
            return exact
        }
        return variants.first ?? rep
    }

    /// Effective UI density of a given "looks like" size on this panel.
    func uiPPI(looksLikeWidth: Int, looksLikeHeight: Int) -> Double {
        guard diagonalInches > 0 else { return 0 }
        let dw = Double(looksLikeWidth), dh = Double(looksLikeHeight)
        return (dw * dw + dh * dh).squareRoot() / diagonalInches
    }

    /// Panel aspect ratio (e.g. 1.778 for 16:9).
    var nativeAspect: Double {
        nativePixelHeight > 0 ? Double(nativePixelWidth) / Double(nativePixelHeight) : 0
    }

    /// Whether a looks-like size matches the panel's aspect ratio.
    /// Mismatched sizes letterbox, stretch or crop when applied.
    func fitsPanelAspect(width: Int, height: Int) -> Bool {
        guard nativeAspect > 0, height > 0 else { return true }
        let a = Double(width) / Double(height)
        return abs(a - nativeAspect) / nativeAspect < 0.02
    }
}
