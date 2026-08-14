import AppKit

enum Alerts {
    static func error(_ title: String, _ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: L("alert.ok"))
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    static func info(_ title: String, _ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: L("alert.ok"))
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    /// Returns true if the user chooses to reboot now.
    static func askReboot() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L("alert.rebootTitle")
        alert.informativeText = L("alert.rebootMsg")
        alert.addButton(withTitle: L("alert.rebootNow"))
        alert.addButton(withTitle: L("alert.later"))
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Warns that a mode does not match the panel's aspect ratio.
    /// Returns true if the user wants to apply anyway.
    static func confirmAspectMismatch() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("alert.aspectTitle")
        alert.informativeText = L("alert.aspectMsg")
        alert.addButton(withTitle: L("alert.applyAnyway"))
        alert.addButton(withTitle: L("alert.cancel"))
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
