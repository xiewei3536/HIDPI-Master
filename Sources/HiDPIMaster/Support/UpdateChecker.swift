import Foundation
import AppKit
import UserNotifications

/// Self-updater backed by GitHub Releases:
/// checks `releases/latest`, notifies the user, downloads the .zip asset,
/// swaps the app bundle in place and relaunches.
final class UpdateChecker: NSObject, ObservableObject {
    static let shared = UpdateChecker()
    static let repo = "xiewei3536/HIDPI-Master"

    @Published var isChecking = false

    private var timer: Timer?
    private var pendingRelease: Release?

    struct Release {
        let version: String
        let zipURL: URL
        let pageURL: URL
        let notes: String
    }

    // MARK: - Scheduling

    func startAutoCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard ProfileStore.shared.autoCheckUpdates else { return }
            self?.check(userInitiated: false)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            guard ProfileStore.shared.autoCheckUpdates else { return }
            self?.check(userInitiated: false)
        }
    }

    // MARK: - Check

    func check(userInitiated: Bool) {
        guard !isChecking else { return }
        isChecking = true
        fetchLatest { [weak self] release in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isChecking = false
                guard let release else {
                    if userInitiated { Alerts.error(L("update.errTitle"), L("update.errMsg")) }
                    return
                }
                if Self.isNewer(release.version, than: SystemInfo.appVersion) {
                    if userInitiated {
                        self.promptInstall(release)
                    } else {
                        self.notify(release)
                    }
                } else if userInitiated {
                    Alerts.info(L("update.upToDateTitle"), L("update.upToDateMsg", SystemInfo.appVersion))
                }
            }
        }
    }

    private func fetchLatest(_ completion: @escaping (Release?) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else {
            return completion(nil)
        }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 20
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let page = json["html_url"] as? String,
                  let assets = json["assets"] as? [[String: Any]],
                  let zip = assets.compactMap({ $0["browser_download_url"] as? String })
                      .first(where: { $0.hasSuffix(".zip") }),
                  let zipURL = URL(string: zip),
                  let pageURL = URL(string: page)
            else { return completion(nil) }
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            completion(Release(version: version, zipURL: zipURL, pageURL: pageURL,
                               notes: json["body"] as? String ?? ""))
        }.resume()
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: - Notify (push-style banner)

    private func notify(_ release: Release) {
        pendingRelease = release
        guard Bundle.main.bundleIdentifier != nil else { return promptInstall(release) }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    let content = UNMutableNotificationContent()
                    content.title = L("update.notifyTitle")
                    content.body = L("update.notifyBody", release.version)
                    content.sound = .default
                    let req = UNNotificationRequest(identifier: "update-\(release.version)",
                                                    content: content, trigger: nil)
                    center.add(req)
                } else {
                    self.promptInstall(release)
                }
            }
        }
    }

    /// Called when the user taps the update notification.
    func promptPending() {
        if let r = pendingRelease { promptInstall(r) }
    }

    // MARK: - Install

    func promptInstall(_ release: Release) {
        pendingRelease = release
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L("update.availableTitle", release.version)
        let notes = String(release.notes.prefix(500))
        alert.informativeText = L("update.availableMsg") + (notes.isEmpty ? "" : "\n\n" + notes)
        alert.addButton(withTitle: L("update.installNow"))
        alert.addButton(withTitle: L("alert.later"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            install(release)
        }
    }

    private func install(_ release: Release) {
        URLSession.shared.downloadTask(with: release.zipURL) { tmp, _, err in
            guard let tmp else {
                DispatchQueue.main.async {
                    Alerts.error(L("update.errTitle"), err?.localizedDescription ?? L("update.errMsg"))
                }
                return
            }
            do {
                let fm = FileManager.default
                let workDir = fm.temporaryDirectory
                    .appendingPathComponent("hidpimaster-update-\(release.version)")
                try? fm.removeItem(at: workDir)
                try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
                let zipPath = workDir.appendingPathComponent("update.zip")
                try fm.moveItem(at: tmp, to: zipPath)

                try Self.runTool("/usr/bin/ditto", ["-xk", zipPath.path, workDir.path])
                guard let appName = try fm.contentsOfDirectory(atPath: workDir.path)
                    .first(where: { $0.hasSuffix(".app") }) else {
                    throw PrivilegedRunner.RunError(message: "No .app found in update archive")
                }
                let newApp = workDir.appendingPathComponent(appName)
                try? Self.runTool("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

                let target = Bundle.main.bundleURL
                guard target.pathExtension == "app" else {
                    throw PrivilegedRunner.RunError(message: "Not running from an app bundle")
                }
                let parent = target.deletingLastPathComponent().path
                if fm.isWritableFile(atPath: parent) {
                    try? fm.removeItem(at: target)
                    try fm.copyItem(at: newApp, to: target)
                } else {
                    try PrivilegedRunner.run("rm -rf '\(target.path)' && cp -R '\(newApp.path)' '\(target.path)'")
                }

                DispatchQueue.main.async {
                    let relaunch = Process()
                    relaunch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    relaunch.arguments = ["-n", target.path]
                    try? relaunch.run()
                    NSApp.terminate(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    Alerts.error(L("update.errTitle"), error.localizedDescription)
                }
            }
        }.resume()
    }

    @discardableResult
    private static func runTool(_ path: String, _ args: [String]) throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            throw PrivilegedRunner.RunError(message: "\(path) exited \(p.terminationStatus)")
        }
        return p.terminationStatus
    }
}
