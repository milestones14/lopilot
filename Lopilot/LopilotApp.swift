import SwiftUI

@main
struct LopilotApp: App {
    var body: some Scene {
        let _ = AppTracker.shared // Start monitoring apps
        
        WindowGroup {
            ContentView()
                .frame(minWidth: 1100, minHeight: 645)
        }
    }
}
