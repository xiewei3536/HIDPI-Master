import Foundation

private extension Data {
    func readBE32(_ offset: Int) -> UInt32 {
        guard count >= offset + 4 else { return 0 }
        return (UInt32(self[startIndex + offset]) << 24)
            | (UInt32(self[startIndex + offset + 1]) << 16)
            | (UInt32(self[startIndex + offset + 2]) << 8)
            | UInt32(self[startIndex + offset + 3])
    }
}

/// Intel path: install a display override plist with `scale-resolutions`
/// under /Library/Displays (same location and entry format as one-key-hidpi).
/// Takes effect after a reboot. SIP stays untouched: the folder lives outside
/// the sealed system volume.
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

    /// 8-byte big-endian width/height entry — the classic format macOS has
    /// honored on Intel since 10.8.
    private static func scaleData(width: Int, height: Int) -> Data {
        var data = Data()
        for v in [UInt32(width), UInt32(height)] {
            var be = v.bigEndian
            withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
        }
        return data
    }

    private static func existingPlist(for display: DisplayInfo) -> [String: Any] {
        guard let data = FileManager.default.contents(atPath: productFile(for: display)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return plist
    }

    /// Backing pixel sizes already declared in the installed override.
    static func installedPixelSizes(for display: DisplayInfo) -> [(w: Int, h: Int)] {
        let entries = existingPlist(for: display)["scale-resolutions"] as? [Data] ?? []
        return entries.compactMap { d in
            guard d.count >= 8 else { return nil }
            return (Int(d.readBE32(0)), Int(d.readBE32(4)))
        }
    }

    /// Builds the override plist and installs it with admin rights.
    /// Merges into an existing override (EDID patches, icons and previously
    /// added sizes are preserved). `looksLikeSizes` are UI sizes; backing
    /// entries are written at 2×.
    static func install(for display: DisplayInfo, looksLikeSizes: [(w: Int, h: Int)]) throws {
        var plist = existingPlist(for: display)
        var entries = plist["scale-resolutions"] as? [Data] ?? []
        var seen = Set(entries.compactMap { d -> String? in
            d.count >= 8 ? "\(d.readBE32(0))x\(d.readBE32(4))" : nil
        })
        for size in looksLikeSizes {
            let bw = size.w * 2, bh = size.h * 2
            if seen.insert("\(bw)x\(bh)").inserted {
                entries.append(scaleData(width: bw, height: bh))
            }
        }
        plist["DisplayVendorID"] = Int(display.vendorID)
        plist["DisplayProductID"] = Int(display.productID)
        plist["scale-resolutions"] = entries
        if plist["target-default-ppmm"] == nil {
            plist["target-default-ppmm"] = 10.0699301
        }

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let tmp = NSTemporaryDirectory() + "hidpimaster-override-\(display.vendorID)-\(display.productID).plist"
        try data.write(to: URL(fileURLWithPath: tmp))

        let dir = vendorDir(for: display)
        let file = productFile(for: display)
        let script = """
        mkdir -p '\(dir)' && \
        cp '\(tmp)' '\(file)' && \
        chown root:wheel '\(file)' && chmod 644 '\(file)' && \
        defaults write /Library/Preferences/com.apple.windowserver.plist DisplayResolutionEnabled -bool true
        """
        try PrivilegedRunner.run(script)
    }

    static func uninstall(for display: DisplayInfo) throws {
        let file = productFile(for: display)
        try PrivilegedRunner.run("rm -f '\(file)'")
    }
}
