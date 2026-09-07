import Foundation
import CoreGraphics

struct Recommendation: Identifiable {
    let looksLikeWidth: Int
    let looksLikeHeight: Int
    let mode: ModeInfo?         // nil = mode not available until HiDPI is enabled
    let score: Double
    let reasonKeys: [String]
    let isTop: Bool

    var id: String { "\(looksLikeWidth)x\(looksLikeHeight)" }
}

/// Scores "looks like" sizes for a panel: balance between comfortable UI size
/// (target effective density scaled by screen size, shifted by the user's
/// preference) and text sharpness (2× Retina best).
enum RecommendationEngine {

    /// Largest HiDPI backing width we ever create (7680×4320 is refused by
    /// most GPUs/drivers and macOS itself never offers it).
    static let maxBackingWidth = 7000

    /// Comfortable effective density target. Bigger screens are viewed from
    /// farther away, so they tolerate (and prefer) a lower effective PPI.
    static func targetUIPPI(diagonalInches d: Double) -> Double {
        switch d {
        case ..<21: return 102
        case ..<25: return 99          // 24" — e.g. looks-like 1920×1080
        case ..<29: return 108         // 27" — e.g. looks-like 2560×1440
        case ..<33: return 100         // 32" — e.g. looks-like 2560×1440 slightly roomy
        default:    return 95
        }
    }

    /// Target adjusted for the panel and the user: a low-density panel
    /// (e.g. 27″ 1080p ≈ 81 PPI) cannot comfortably show a denser UI than its
    /// native size, and the "bigger text / more space" preference shifts it.
    static func effectiveTargetUIPPI(for display: DisplayInfo) -> Double {
        var t = targetUIPPI(diagonalInches: display.diagonalInches)
        if display.ppi > 20 { t = min(t, display.ppi) }
        t += ProfileStore.shared.sizePreference.ppiBias
        return max(t, 40)
    }

    static func sizeScore(uiPPI: Double, target: Double) -> Double {
        let sigma = 16.0
        let delta = (uiPPI - target) / sigma
        return exp(-delta * delta)
    }

    static func sharpnessScore(for mode: ModeInfo, native: (w: Int, h: Int)) -> Double {
        if mode.isHiDPI {
            if abs(mode.scale - 2.0) < 0.01 { return 1.0 }
            return 0.82
        }
        if mode.pixelWidth == native.w && mode.pixelHeight == native.h { return 0.5 }
        return 0.22
    }

    /// Rank the modes that exist right now.
    /// HiDPI-only and panel-aspect-only: a blurry or ill-fitting mode is never
    /// recommended. Empty when the panel size is unknown or no HiDPI exists.
    static func recommend(for display: DisplayInfo) -> [Recommendation] {
        let pool = display.uniqueHiDPIModes.filter {
            display.fitsPanelAspect(width: $0.width, height: $0.height)
        }
        guard display.diagonalInches > 1, !pool.isEmpty else { return [] }
        let target = effectiveTargetUIPPI(for: display)
        let native = (display.nativePixelWidth, display.nativePixelHeight)

        var recos: [Recommendation] = []
        for mode in pool {
            let uiPPI = display.uiPPI(looksLikeWidth: mode.width, looksLikeHeight: mode.height)
            let size = sizeScore(uiPPI: uiPPI, target: target)
            let sharp = sharpnessScore(for: mode, native: native)
            let score = 0.55 * size + 0.45 * sharp

            var reasons: [String] = []
            reasons.append(abs(mode.scale - 2.0) < 0.01 ? "reco.reason.sharp2x" : "reco.reason.sharpFrac")
            if uiPPI < target - 12 {
                reasons.append("reco.reason.large")
            } else if uiPPI > target + 12 {
                reasons.append("reco.reason.small")
            } else {
                reasons.append("reco.reason.comfy")
            }
            if mode.pixelWidth > display.nativePixelWidth {
                reasons.append("reco.reason.downscale")
            }

            recos.append(Recommendation(
                looksLikeWidth: mode.width, looksLikeHeight: mode.height,
                mode: mode, score: score, reasonKeys: reasons, isTop: false))
        }
        recos.sort { $0.score > $1.score }
        if let first = recos.first {
            recos[0] = Recommendation(
                looksLikeWidth: first.looksLikeWidth, looksLikeHeight: first.looksLikeHeight,
                mode: first.mode, score: first.score, reasonKeys: first.reasonKeys, isTop: true)
        }
        return recos
    }

    /// Friendly size label ("extra large" … "extra small") for a looks-like
    /// size, relative to the (preference-adjusted) comfortable target.
    /// Falls back to rank among HiDPI modes when the panel size is unknown.
    static func sizeLevelKey(for display: DisplayInfo, looksLikeWidth: Int, looksLikeHeight: Int) -> String {
        if display.diagonalInches > 1 {
            let target = effectiveTargetUIPPI(for: display)
            let ui = display.uiPPI(looksLikeWidth: looksLikeWidth, looksLikeHeight: looksLikeHeight)
            switch ui - target {
            case ..<(-22): return "size.level.xl"
            case ..<(-9):  return "size.level.l"
            case ...9:     return "size.level.just"
            case ...22:    return "size.level.s"
            default:       return "size.level.xs"
            }
        }
        let sorted = display.uniqueHiDPIModes.sorted { $0.width < $1.width }
        guard sorted.count > 1, let idx = sorted.firstIndex(where: { $0.width == looksLikeWidth }) else {
            return "size.level.just"
        }
        switch Double(idx) / Double(sorted.count - 1) {
        case ..<0.2:  return "size.level.xl"
        case ..<0.45: return "size.level.l"
        case ...0.6:  return "size.level.just"
        case ...0.8:  return "size.level.s"
        default:      return "size.level.xs"
        }
    }

    static func sizeLevelKey(for display: DisplayInfo, mode: ModeInfo) -> String {
        sizeLevelKey(for: display, looksLikeWidth: mode.width, looksLikeHeight: mode.height)
    }

    /// Same-aspect "looks like" sizes worth creating for this panel,
    /// largest → smallest. All render at 2× and stay within GPU-safe limits.
    static func candidateLooksLikeSizes(for display: DisplayInfo) -> [(w: Int, h: Int)] {
        let nw = display.nativePixelWidth, nh = display.nativePixelHeight
        guard nw > 0, nh > 0 else { return [] }
        let fractions: [Double] = [1.0, 0.9, 0.8, 0.75, 17.0 / 24.0, 2.0 / 3.0, 0.625, 0.6, 0.5625, 0.5]
        var seen = Set<String>()
        var out: [(w: Int, h: Int)] = []
        for f in fractions {
            var w = Int((Double(nw) * f).rounded())
            var h = Int((Double(nh) * f).rounded())
            w -= w % 2
            h -= h % 2
            guard w >= 1280, w * 2 <= maxBackingWidth else { continue }
            if seen.insert("\(w)x\(h)").inserted { out.append((w, h)) }
        }
        return out
    }

    /// A candidate looks-like size for the enable/add flow.
    /// `fits == false` means the size differs from the panel aspect ratio and
    /// would letterbox/stretch — shown with a warning mark, never recommended.
    struct SizeCandidate: Identifiable {
        let w: Int
        let h: Int
        let fits: Bool
        var id: String { "\(w)x\(h)" }
    }

    /// Maximum possible HiDPI candidate set for this panel: every same-aspect
    /// fraction of native plus a catalog of common sizes across aspect
    /// families (16:9, 16:10, ultrawide, 4:3/5:4), flagged by fit.
    static func extendedCandidates(for display: DisplayInfo) -> [SizeCandidate] {
        var out: [SizeCandidate] = candidateLooksLikeSizes(for: display)
            .map { SizeCandidate(w: $0.w, h: $0.h, fits: true) }
        var seen = Set(out.map(\.id))

        let catalog: [(Int, Int)] = [
            (3840, 2160), (3200, 1800), (2560, 1440), (2304, 1296), (2048, 1152),
            (1920, 1080), (1760, 990), (1600, 900), (1440, 810), (1360, 765), (1280, 720),
            (2560, 1600), (1920, 1200), (1680, 1050), (1440, 900), (1280, 800),
            (3440, 1440), (2560, 1080),
            (1600, 1200), (1400, 1050), (1280, 960), (1280, 1024), (1024, 768),
        ]
        for (w, h) in catalog {
            guard w <= display.nativePixelWidth, w >= 1024, w * 2 <= maxBackingWidth else { continue }
            if seen.insert("\(w)x\(h)").inserted {
                out.append(SizeCandidate(w: w, h: h, fits: display.fitsPanelAspect(width: w, height: h)))
            }
        }
        return out.sorted { a, b in
            if a.fits != b.fits { return a.fits }
            return a.w > b.w
        }
    }

    /// Best "looks like" size to suggest before HiDPI exists (enable flow).
    static func bestCandidate(for display: DisplayInfo) -> (w: Int, h: Int)? {
        let target = effectiveTargetUIPPI(for: display)
        let ranked = candidateLooksLikeSizes(for: display).map { c -> ((w: Int, h: Int), Double) in
            let ui = display.uiPPI(looksLikeWidth: c.w, looksLikeHeight: c.h)
            return (c, sizeScore(uiPPI: ui, target: target))
        }
        return ranked.max(by: { $0.1 < $1.1 })?.0
    }
}
