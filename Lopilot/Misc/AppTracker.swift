import AppKit

class AppTracker {
    static let shared = AppTracker()
    var lastActiveApp: String = "a macOS application"

    init() {
        // Watch for whenever the user switches apps
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               let name = app.localizedName,
               // Ignore Lopilot and Finder so we keep the "Work" app in memory
               name != "Lopilot" && name != "Finder" {
                self.lastActiveApp = name
            }
        }
    }
}
