import Foundation
import CoreGraphics

/// One selectable display mode (deduplicated per width×height×density).
struct ModeInfo: Identifiable, Hashable {
    let mode: CGDisplayMode
    let width: Int          // points ("looks like")
    let height: Int
    let pixelWidth: Int     // backing pixels
    let pixelHeight: Int
    let refreshRate: Double

    var isHiDPI: Bool { pixelWidth > width }
    var scale: Double { width > 0 ? Double(pixelWidth) / Double(width) : 1 }

    /// Identity including refresh rate (one entry per selectable Hz).
    var id: String { "\(resolutionKey)@\(Int(refreshRate.rounded()))" }
    /// Identity of the resolution/density pair, ignoring refresh rate.
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
    let physicalSize: CGSize        // millimeters
    let nativePixelWidth: Int
    let nativePixelHeight: Int
    let currentMode: ModeInfo?
    let modes: [ModeInfo]           // sorted large → small
    let mirrorsDisplayID: CGDirectDisplayID  // non-zero when this display mirrors another

    /// Stable key across reconnects for saving profiles.
    var persistentKey: String { "\(vendorID)-\(productID)-\(nativePixelWidth)x\(nativePixelHeight)" }

    var diagonalInches: Double {
        let w = physicalSize.width, h = physicalSize.height
        guard w > 0, h > 0 else { return 0 }
        return (w * w + h * h).squareRoot() / 25.4
    }

    var ppi: Double {
        guard diagonalInches > 0 else { return 0 }
        let dw = Double(nativePixelWidth), dh = Double(nativePixelHeight)
        return (dw * dw + dh * dh).squareRoot() / diagonalInches
    }

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
    /// Mismatched sizes will letterbox, stretch or crop when applied.
    func fitsPanelAspect(width: Int, height: Int) -> Bool {
        guard nativeAspect > 0, height > 0 else { return true }
        let a = Double(width) / Double(height)
        return abs(a - nativeAspect) / nativeAspect < 0.02
    }
}
