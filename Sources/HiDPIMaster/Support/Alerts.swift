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

    struct RebootDecision {
        let rebootNow: Bool
        let autoApplyAfterReboot: Bool
    }

    /// Asks to reboot after an override install; offers to auto-apply the
    /// chosen size once the Mac is back (which turns on launch at login).
    static func askReboot() -> RebootDecision {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L("alert.rebootTitle")
        alert.informativeText = L("alert.rebootMsg")
        alert.addButton(withTitle: L("alert.rebootNow"))
        alert.addButton(withTitle: L("alert.later"))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = L("alert.autoApplyAfterReboot")
        alert.suppressionButton?.state = .on
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        return RebootDecision(rebootNow: response == .alertFirstButtonReturn,
                              autoApplyAfterReboot: alert.suppressionButton?.state == .on)
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

    /// "Does this look right?" with a countdown bar. Returns true to keep the
    /// new setting; false (button or timeout) means revert.
    static func confirmKeep(seconds: Int = 12) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L("keep.title")
        alert.informativeText = L("keep.desc")
        alert.addButton(withTitle: L("keep.keep"))
        alert.addButton(withTitle: L("keep.revert"))

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 44))
        let bar = NSProgressIndicator(frame: NSRect(x: 0, y: 26, width: 280, height: 12))
        bar.isIndeterminate = false
        bar.style = .bar
        bar.minValue = 0
        bar.maxValue = Double(seconds)
        bar.doubleValue = Double(seconds)
        let label = NSTextField(labelWithString: L("keep.countdown", seconds))
        label.frame = NSRect(x: 0, y: 0, width: 280, height: 18)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        container.addSubview(bar)
        container.addSubview(label)
        alert.accessoryView = container

        var remaining = seconds
        let timer = Timer(timeInterval: 1, repeats: true) { t in
            remaining -= 1
            bar.doubleValue = Double(max(remaining, 0))
            label.stringValue = L("keep.countdown", max(remaining, 0))
            if remaining <= 0 {
                t.invalidate()
                NSApp.stopModal(withCode: .abort)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        timer.invalidate()
        return response == .alertFirstButtonReturn
    }
}
