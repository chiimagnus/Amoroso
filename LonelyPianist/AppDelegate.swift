import AppKit

@MainActor
@objc final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Prevent AppKit from creating an untitled new window when app is activated.
    func applicationShouldOpenUntitledFile(_: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        if let mainWindow = sender.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            mainWindow.makeKeyAndOrderFront(nil)
            sender.activate(ignoringOtherApps: true)
            return true
        }

        if let anyWindow = sender.windows.first {
            anyWindow.makeKeyAndOrderFront(nil)
            sender.activate(ignoringOtherApps: true)
        }
        return true
    }
}
