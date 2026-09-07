import AppKit
import SwiftUI
import UserNotifications

/// Payload for the menu-bar quick-switch items.
final class QuickSwitchTarget: NSObject {
    let display: DisplayInfo
    let mode: ModeInfo
    init(display: DisplayInfo, mode: ModeInfo) {
        self.display = display
        self.mode = mode
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var debugWindow: NSWindow?
    private var heightObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: ContentView.width, height: 520)
        popover.contentViewController = NSHostingController(rootView: ContentView())
        popover.delegate = self

        heightObserver = NotificationCenter.default.addObserver(
            forName: .hidpiContentHeight, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let h = note.userInfo?["height"] as? CGFloat else { return }
            let size = NSSize(width: ContentView.width, height: h)
            if self.popover.contentSize != size { self.popover.contentSize = size }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "sparkles.tv", accessibilityDescription: L("app.name"))
            image?.isTemplate = true
            button.image = image
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        // Restore saved setups (virtual displays, remembered modes, post-reboot wishes)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            DisplayManager.shared.autoApplyIfNeeded()
        }

        // Auto-update checks against GitHub Releases
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
        }
        UpdateChecker.shared.startAutoCheck()

        // First launch: show where we live
        if ProfileStore.shared.isFirstLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.openPopover()
            }
        }

        setupDebugWindowIfRequested()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DisplayManager.shared.teardownForQuit()
    }

    // MARK: - Notifications

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        UpdateChecker.shared.promptPending()
        completionHandler()
    }

    // MARK: - Status item

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }
        togglePopover()
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        DisplayManager.shared.refresh()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Quick size switching per external display
        for d in DisplayManager.shared.externalDisplays {
            let modes = d.uniqueHiDPIModes
                .filter { d.fitsPanelAspect(width: $0.width, height: $0.height) }
                .sorted { $0.width < $1.width }
            guard !modes.isEmpty else { continue }
            let header = NSMenuItem(title: d.name, action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for m in modes {
                let level = L(RecommendationEngine.sizeLevelKey(for: d, mode: m))
                let item = NSMenuItem(title: "\(level)  ·  \(m.width)×\(m.height)",
                                      action: #selector(quickSwitch(_:)), keyEquivalent: "")
                item.target = self
                item.isEnabled = true
                item.indentationLevel = 1
                item.representedObject = QuickSwitchTarget(display: d, mode: m)
                item.state = d.currentMode?.resolutionKey == m.resolutionKey ? .on : .off
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        let openItem = NSMenuItem(title: L("menu.open"), action: #selector(openFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        let aboutItem = NSMenuItem(title: L("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        let updateItem = NSMenuItem(title: L("update.check"), action: #selector(checkUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: L("footer.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func quickSwitch(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? QuickSwitchTarget else { return }
        DisplayManager.shared.applySafely(mode: target.display.variantKeepingRefresh(of: target.mode),
                                          to: target.display)
    }

    @objc private func openFromMenu() {
        openPopover()
    }

    @objc private func showAbout() {
        Alerts.info(L("app.name") + " v" + SystemInfo.appVersion, L("about.text"))
    }

    @objc private func checkUpdates() {
        UpdateChecker.shared.check(userInitiated: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Debug helpers (HIDPI_DEBUG_WINDOW=1 / HIDPI_SNAPSHOT=/path.png)

    private func setupDebugWindowIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard env["HIDPI_DEBUG_WINDOW"] == "1" || env["HIDPI_SNAPSHOT"] != nil else { return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: ContentView.width, height: 620),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "HiDPI Master (debug)"
        window.contentViewController = NSHostingController(rootView: ContentView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        debugWindow = window

        if let path = env["HIDPI_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.snapshot(to: path)
                NSApp.terminate(nil)
            }
        }
    }

    private func snapshot(to path: String) {
        guard let view = debugWindow?.contentView else { return }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
