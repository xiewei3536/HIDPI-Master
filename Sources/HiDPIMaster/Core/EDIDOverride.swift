import Foundation

/// Intel path: install a display override plist with `scale-resolutions`
/// under /Library/Displays. Takes effect after a reboot. No SIP change needed
/// on macOS 10.15+ (the folder lives outside the sealed system volume).
enum EDIDOverrideInstaller {

    static let overridesRoot = "/Library/Displays/Contents/Resources/Overrides"

    static func vendorDir(for display: DisplayInfo) -> String {
        overridesRoot + "/DisplayVendorID-" + String(format: "%x", display.vendorID)
    }

    static func productFile(for display: DisplayInfo) -> String {
        vendorDir(for: display) + "/DisplayProductID-" + String(format: "%x", display.productID)
    }

    static func isInstalled(for display: DisplayInfo) -> Bool {
        FileManager.default.fileExists(atPath: productFile(for: display))
    }

    private static func scaleData(width: Int, height: Int) -> Data {
        var data = Data()
        for v in [UInt32(width), UInt32(height)] {
            var be = v.bigEndian
            withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
        }
        return data
    }

    /// Builds the override plist and installs it with admin rights.
    /// `looksLikeSizes` are UI sizes; backing entries are injected at 2×.
    static func install(for display: DisplayInfo, looksLikeSizes: [(w: Int, h: Int)]) throws {
        var entries: [Data] = []
        var seen = Set<String>()
        for size in looksLikeSizes {
            let bw = size.w * 2, bh = size.h * 2
            let key = "\(bw)x\(bh)"
            if seen.insert(key).inserted {
                entries.append(scaleData(width: bw, height: bh))
            }
        }
        // Also expose the native resolution itself as a plain mode
        entries.append(scaleData(width: display.nativePixelWidth, height: display.nativePixelHeight))

        let plist: [String: Any] = [
            "DisplayProductName": "\(display.name) (HiDPI)",
            "DisplayVendorID": Int(display.vendorID),
            "DisplayProductID": Int(display.productID),
            "scale-resolutions": entries,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let tmp = NSTemporaryDirectory() + "hidpimaster-override-\(display.vendorID)-\(display.productID).plist"
        try data.write(to: URL(fileURLWithPath: tmp))

        let dir = vendorDir(for: display)
        let file = productFile(for: display)
        let script = """
        mkdir -p '\(dir)' && \
        cp '\(tmp)' '\(file)' && \
        chmod 644 '\(file)' && \
        defaults write /Library/Preferences/com.apple.windowserver.plist DisplayResolutionEnabled -bool true
        """
        try PrivilegedRunner.run(script)
    }

    static func uninstall(for display: DisplayInfo) throws {
        let file = productFile(for: display)
        try PrivilegedRunner.run("rm -f '\(file)'")
    }
}
