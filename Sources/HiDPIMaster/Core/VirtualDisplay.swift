import Foundation
import AppKit
import CoreGraphics

enum HiDPIError: LocalizedError {
    case virtualUnsupported
    case creationFailed
    case mirrorFailed
    case modeNotFound

    var errorDescription: String? {
        switch self {
        case .virtualUnsupported: return L("err.unsupportedVirtual")
        case .creationFailed: return L("err.creationFailed")
        case .mirrorFailed: return L("err.mirrorFailed")
        case .modeNotFound: return L("err.modeNotFound")
        }
    }
}

/// Apple Silicon path (also works on Intel without reboot):
/// create a virtual HiDPI display via private CoreGraphics classes
/// (the same technique used by BetterDummy/BetterDisplay), then mirror the
/// physical panel onto it. All calls are resolved at runtime and guarded.
final class VirtualDisplayController {
    static let shared = VirtualDisplayController()

    /// physical persistentKey → virtual display object (kept alive) & its ID
    private var virtualDisplays: [String: (object: NSObject, id: CGDirectDisplayID)] = [:]

    private init() {}

    var isSupported: Bool {
        NSClassFromString("CGVirtualDisplay") != nil &&
        NSClassFromString("CGVirtualDisplayDescriptor") != nil &&
        NSClassFromString("CGVirtualDisplaySettings") != nil &&
        NSClassFromString("CGVirtualDisplayMode") != nil
    }

    func isVirtualDisplay(_ id: CGDirectDisplayID) -> Bool {
        guard id != 0 else { return false }
        return virtualDisplays.values.contains { $0.id == id }
    }

    func virtualID(forPhysicalKey key: String) -> CGDirectDisplayID? {
        virtualDisplays[key]?.id
    }

    // MARK: - Dynamic ObjC helpers

    private func allocInstance(_ cls: AnyClass) -> NSObject? {
        let allocSel = NSSelectorFromString("alloc")
        guard let obj = (cls as AnyObject).perform(allocSel)?.takeUnretainedValue() as? NSObject else {
            return nil
        }
        return obj
    }

    private func makeMode(width: Int, height: Int, refresh: Double) -> NSObject? {
        guard let cls = NSClassFromString("CGVirtualDisplayMode"),
              let raw = allocInstance(cls) else { return nil }
        let sel = NSSelectorFromString("initWithWidth:height:refreshRate:")
        guard raw.responds(to: sel), let imp = raw.method(for: sel) else { return nil }
        typealias InitFn = @convention(c) (NSObject, Selector, UInt, UInt, Double) -> NSObject?
        let fn = unsafeBitCast(imp, to: InitFn.self)
        return fn(raw, sel, UInt(width), UInt(height), refresh)
    }

    // MARK: - Enable / disable

    /// Creates the virtual HiDPI display for `display`, mirrors the physical
    /// panel onto it, and switches to `primaryLooksLike`.
    func enableHiDPI(for display: DisplayInfo, primaryLooksLike: (w: Int, h: Int)) throws {
        guard isSupported else { throw HiDPIError.virtualUnsupported }

        // Reuse existing virtual display if present
        if let existing = virtualDisplays[display.persistentKey] {
            try mirror(physical: display.id, onto: existing.id)
            _ = setMode(virtualID: existing.id,
                        looksLikeWidth: primaryLooksLike.w,
                        looksLikeHeight: primaryLooksLike.h)
            persist(display: display, looksLike: primaryLooksLike)
            return
        }

        guard let descClass = NSClassFromString("CGVirtualDisplayDescriptor"),
              let settingsClass = NSClassFromString("CGVirtualDisplaySettings"),
              let displayClass = NSClassFromString("CGVirtualDisplay"),
              let descriptor = allocInstance(descClass),
              descriptor.responds(to: NSSelectorFromString("init"))
        else { throw HiDPIError.virtualUnsupported }

        _ = descriptor.perform(NSSelectorFromString("init"))

        var candidates = RecommendationEngine.candidateLooksLikeSizes(for: display)
        // Always include the requested size (it may come from the extended
        // catalog, e.g. an aspect-mismatched pick the user confirmed).
        if !candidates.contains(where: { $0.w == primaryLooksLike.w && $0.h == primaryLooksLike.h }) {
            candidates.append((primaryLooksLike.w, primaryLooksLike.h))
        }
        let maxW = max(display.nativePixelWidth, (candidates.map { $0.w * 2 }.max() ?? 0))
        let maxH = max(display.nativePixelHeight, (candidates.map { $0.h * 2 }.max() ?? 0))

        descriptor.setValue("\(display.name) (HiDPI)", forKey: "name")
        descriptor.setValue(NSNumber(value: UInt32(0x4869)), forKey: "vendorID")   // "Hi"
        descriptor.setValue(NSNumber(value: display.productID), forKey: "productID")
        descriptor.setValue(NSNumber(value: display.vendorID &+ display.productID), forKey: "serialNum")
        descriptor.setValue(NSNumber(value: UInt(maxW)), forKey: "maxPixelsWide")
        descriptor.setValue(NSNumber(value: UInt(maxH)), forKey: "maxPixelsHigh")
        let sizeMM = display.physicalSize
        if sizeMM.width > 0 {
            descriptor.setValue(NSValue(size: NSSize(width: sizeMM.width, height: sizeMM.height)),
                                forKey: "sizeInMillimeters")
        }
        // sRGB primaries + D65 white point
        descriptor.setValue(NSValue(point: NSPoint(x: 0.640, y: 0.330)), forKey: "redPrimary")
        descriptor.setValue(NSValue(point: NSPoint(x: 0.300, y: 0.600)), forKey: "greenPrimary")
        descriptor.setValue(NSValue(point: NSPoint(x: 0.150, y: 0.060)), forKey: "bluePrimary")
        descriptor.setValue(NSValue(point: NSPoint(x: 0.3127, y: 0.3290)), forKey: "whitePoint")
        descriptor.setValue(DispatchQueue.main, forKey: "queue")

        guard let rawDisplay = allocInstance(displayClass) else { throw HiDPIError.creationFailed }
        let initSel = NSSelectorFromString("initWithDescriptor:")
        guard rawDisplay.responds(to: initSel), let initIMP = rawDisplay.method(for: initSel) else {
            throw HiDPIError.creationFailed
        }
        typealias InitDescFn = @convention(c) (NSObject, Selector, NSObject) -> NSObject?
        let initFn = unsafeBitCast(initIMP, to: InitDescFn.self)
        guard let virtual = initFn(rawDisplay, initSel, descriptor) else {
            throw HiDPIError.creationFailed
        }

        // Build HiDPI mode list (2× backing for every candidate looks-like size)
        var modeObjects: [NSObject] = []
        let refresh = max(display.currentMode?.refreshRate ?? 60, 30)
        for c in candidates {
            if let m = makeMode(width: c.w * 2, height: c.h * 2, refresh: refresh) {
                modeObjects.append(m)
            }
        }
        if modeObjects.isEmpty { throw HiDPIError.creationFailed }

        guard let settings = allocInstance(settingsClass),
              settings.responds(to: NSSelectorFromString("init"))
        else { throw HiDPIError.creationFailed }
        _ = settings.perform(NSSelectorFromString("init"))
        settings.setValue(NSNumber(value: 2), forKey: "hiDPI")
        settings.setValue(modeObjects as NSArray, forKey: "modes")

        let applySel = NSSelectorFromString("applySettings:")
        guard virtual.responds(to: applySel), let applyIMP = virtual.method(for: applySel) else {
            throw HiDPIError.creationFailed
        }
        typealias ApplyFn = @convention(c) (NSObject, Selector, NSObject) -> Bool
        let applyFn = unsafeBitCast(applyIMP, to: ApplyFn.self)
        guard applyFn(virtual, applySel, settings) else { throw HiDPIError.creationFailed }

        guard let idNum = virtual.value(forKey: "displayID") as? NSNumber else {
            throw HiDPIError.creationFailed
        }
        let virtualID = CGDirectDisplayID(idNum.uint32Value)
        virtualDisplays[display.persistentKey] = (virtual, virtualID)

        // Give WindowServer a moment to register the display, then mirror + set mode
        Thread.sleep(forTimeInterval: 0.4)
        try mirror(physical: display.id, onto: virtualID)
        Thread.sleep(forTimeInterval: 0.3)
        _ = setMode(virtualID: virtualID,
                    looksLikeWidth: primaryLooksLike.w,
                    looksLikeHeight: primaryLooksLike.h)

        persist(display: display, looksLike: primaryLooksLike)
    }

    private func persist(display: DisplayInfo, looksLike: (w: Int, h: Int)) {
        ProfileStore.shared.setVirtualConfig(
            .init(width: looksLike.w, height: looksLike.h),
            for: display.persistentKey
        )
    }

    func disableHiDPI(for display: DisplayInfo) {
        let key = display.persistentKey
        // Undo mirroring first
        var config: CGDisplayConfigRef?
        if CGBeginDisplayConfiguration(&config) == .success {
            CGConfigureDisplayMirrorOfDisplay(config, display.id, kCGNullDirectDisplay)
            CGCompleteDisplayConfiguration(config, .permanently)
        }
        virtualDisplays.removeValue(forKey: key) // releasing the object destroys the display
        ProfileStore.shared.setVirtualConfig(nil, for: key)
    }

    func disableAll() {
        let mgr = DisplayManager.shared
        for d in mgr.displays where isVirtualDisplay(d.mirrorsDisplayID) {
            disableHiDPI(for: d)
        }
        virtualDisplays.removeAll()
    }

    // MARK: - Mirroring & modes

    private func mirror(physical: CGDirectDisplayID, onto virtualID: CGDirectDisplayID) throws {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { throw HiDPIError.mirrorFailed }
        let err = CGConfigureDisplayMirrorOfDisplay(config, physical, virtualID)
        guard err == .success, CGCompleteDisplayConfiguration(config, .permanently) == .success else {
            CGCancelDisplayConfiguration(config)
            throw HiDPIError.mirrorFailed
        }
    }

    /// Switch the virtual display to the HiDPI mode that "looks like" w×h.
    func setMode(virtualID: CGDirectDisplayID, looksLikeWidth: Int, looksLikeHeight: Int) -> Bool {
        let options = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
        guard let all = CGDisplayCopyAllDisplayModes(virtualID, options) as? [CGDisplayMode] else {
            return false
        }
        let target = all.first {
            $0.width == looksLikeWidth && $0.height == looksLikeHeight && $0.pixelWidth > $0.width
        } ?? all.first {
            $0.width == looksLikeWidth && $0.height == looksLikeHeight
        }
        guard let mode = target else { return false }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return false }
        CGConfigureDisplayWithDisplayMode(config, virtualID, mode, nil)
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }
}
